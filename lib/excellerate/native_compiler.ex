defmodule ExCellerate.NativeCompiler do
  @moduledoc false
  # Internal: compiles an expression into a real BEAM module so evaluation runs
  # compiled code rather than the :erl_eval interpreter that Code.eval_quoted
  # produces.
  #
  # Two roles live here:
  #
  #   * Phase 1 standalone helpers `compile/2` & `compile!/2` — parse, compile,
  #     and create a module under a UNIQUE name (`ExCellerate.Compiled.E<n>`).
  #     Used by the benchmark in priv/bench/native_bench.exs.
  #   * A GenServer that owns a bounded pool of reusable module-name atoms and
  #     serializes module creation. `compile_cached/3` dedups by {registry, expr}
  #     and falls back to an interpreted closure when the pool is exhausted.

  use GenServer

  alias ExCellerate.{Compiler, Parser}
  alias ExCellerate.NativeCompiler.Slots

  @default_module_limit 4096
  @default_grace_ms 1000

  ## Phase 1 standalone helpers

  @spec compile(String.t(), module() | nil) ::
          {:ok, (ExCellerate.scope() -> any())} | {:error, ExCellerate.Error.t()}
  def compile(expression, registry \\ nil) do
    case Parser.parse(expression) do
      {:ok, ast} ->
        try do
          {:ok, build_module_fun(ast, registry)}
        rescue
          e -> {:error, e}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec compile!(String.t(), module() | nil) :: (ExCellerate.scope() -> any())
  def compile!(expression, registry \\ nil) do
    case compile(expression, registry) do
      {:ok, fun} -> fun
      {:error, error} -> raise error
    end
  end

  ## GenServer

  @doc false
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc false
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent
    }
  end

  @impl true
  def init(opts) do
    # Trap exits so terminate/2 runs on supervisor shutdown: a non-trapping
    # GenServer is killed outright on a :shutdown signal and never gets to clean
    # up the BEAM modules it minted.
    Process.flag(:trap_exit, true)

    cap =
      Keyword.get(
        opts,
        :native_module_limit,
        Application.get_env(:excellerate, :native_module_limit, @default_module_limit)
      )

    grace_ms =
      Keyword.get(
        opts,
        :native_purge_grace_ms,
        Application.get_env(:excellerate, :native_purge_grace_ms, @default_grace_ms)
      )

    {:ok, %{slots: Slots.new(cap), by_key: %{}, grace_ms: grace_ms}}
  end

  # Compiles `elixir_ast` into a native BEAM module, reusing a pooled module
  # name. Dedups by {registry, expr}. Returns:
  #
  #   * {:ok, fun, mod_name}      — native module function
  #   * {:ok, interpreted_fun, nil} — fallback when the pool is full
  #
  # Assumes `elixir_ast` is an already-parsed/compiled, valid AST (produced by
  # Parser + Compiler). Module creation is still guarded so a malformed-AST edge
  # case falls back to an interpreted closure instead of crashing the server.
  @spec compile_cached(module() | nil, String.t(), Macro.t()) ::
          {:ok, (ExCellerate.scope() -> any()), module() | nil}
  def compile_cached(registry, expr, elixir_ast) do
    GenServer.call(__MODULE__, {:compile, registry, expr, elixir_ast})
  end

  # Releases a previously compiled {registry, expr} entry, scheduling its module
  # to be purged after a grace period so its pool slot can be reused. A no-op for
  # unknown keys or interpreted fallbacks (which were never recorded). Async;
  # returns :ok.
  @spec release(module() | nil, String.t()) :: :ok
  def release(registry, expr) do
    GenServer.cast(__MODULE__, {:release, registry, expr})
  end

  @doc false
  # Introspection for deterministic tests. Returns pool counters.
  @spec pool_stats() :: %{
          minted: non_neg_integer(),
          free: non_neg_integer(),
          by_key: non_neg_integer()
        }
  def pool_stats do
    GenServer.call(__MODULE__, :pool_stats)
  end

  @impl true
  def handle_call({:compile, registry, expr, elixir_ast}, _from, state) do
    key = {registry, expr}

    case Map.get(state.by_key, key) do
      nil ->
        case Slots.alloc(state.slots) do
          {:ok, name, slots} ->
            try do
              fun = create_eval_module(name, elixir_ast)
              by_key = Map.put(state.by_key, key, name)
              {:reply, {:ok, fun, name}, %{state | slots: slots, by_key: by_key}}
            rescue
              _ ->
                # Module creation failed (e.g. a malformed AST). Return the slot
                # to the pool and fall back to an interpreted closure without
                # recording it in by_key.
                slots = Slots.free(slots, name)
                {:reply, {:ok, build_interpreted_fun(elixir_ast), nil}, %{state | slots: slots}}
            end

          {:full, slots} ->
            {:reply, {:ok, build_interpreted_fun(elixir_ast), nil}, %{state | slots: slots}}
        end

      mod ->
        {:reply, {:ok, Function.capture(mod, :eval, 1), mod}, state}
    end
  end

  @impl true
  def handle_call(:pool_stats, _from, state) do
    stats = Map.put(Slots.stats(state.slots), :by_key, map_size(state.by_key))
    {:reply, stats, state}
  end

  @impl true
  def handle_cast({:release, registry, expr}, state) do
    key = {registry, expr}

    case Map.get(state.by_key, key) do
      nil ->
        # Unknown key or an interpreted fallback (never recorded) — nothing to do.
        {:noreply, state}

      mod ->
        # Remove the key immediately so dedup won't hand out a module that is
        # about to be purged, then schedule the purge after the grace period.
        by_key = Map.delete(state.by_key, key)
        Process.send_after(self(), {:purge, mod, :delete}, state.grace_ms)
        {:noreply, %{state | by_key: by_key}}
    end
  end

  @impl true
  def handle_info({:purge, mod, phase}, state) do
    # On the first (`:delete`) attempt, mark the current code old so new lookups
    # fail while any process still running the old code keeps doing so until it
    # returns. On `:retry` attempts the code is already old, so calling
    # :code.delete again would log "must be purged before deleting" — skip it.
    if phase == :delete, do: :code.delete(mod)

    case :code.soft_purge(mod) do
      true ->
        # Fully purged (or nothing to purge). The name is now safe to reuse; a
        # later Module.create under it is a fresh definition.
        {:noreply, %{state | slots: Slots.free(state.slots, mod)}}

      false ->
        # Old code still in use by some process. Do NOT free the slot yet;
        # retry after another grace period (delete already happened).
        Process.send_after(self(), {:purge, mod, :retry}, state.grace_ms)
        {:noreply, state}
    end
  end

  @impl true
  def terminate(_reason, state) do
    # Best-effort cleanup of EVERY module this server minted (not just the keys
    # still live in by_key): a module that was released but whose grace purge
    # hasn't fired yet is already gone from by_key, yet still loaded. Leaving any
    # of these loaded makes a later server's Module.create redefine them (the
    # "redefining module ExCellerate.Compiled.S0" warning) and can leave a
    # half-deleted current+old version that corrupts the next lifecycle.
    #
    # The server owns these names and is going down, so hard-purge: :code.delete
    # makes the current version old, then :code.purge removes ANY remaining
    # version unconditionally (soft_purge would skip a referenced version and
    # leave the phantom behind). Ignore results; this is best-effort teardown.
    Enum.each(Slots.minted_names(state.slots), fn mod ->
      :code.delete(mod)
      :code.purge(mod)
    end)

    :ok
  end

  ## Shared helpers

  defp build_module_fun(ast, registry) do
    elixir_ast = Compiler.compile(ast, registry)
    create_eval_module(unique_module_name(), elixir_ast)
  end

  # Creates a `def eval(scope), do: <elixir_ast>` module under `name` and
  # returns a captured reference to it.
  defp create_eval_module(name, elixir_ast) do
    scope_var = Compiler.scope_var()

    body =
      quote do
        def eval(unquote(scope_var)) do
          # Mark the scope param used so scope-less expressions (e.g. "1 + 2")
          # do not emit an unused-variable warning at Module.create time. The
          # interpreted fn-wrapper path does not warn on unused args; match that.
          _ = unquote(scope_var)
          unquote(elixir_ast)
        end
      end

    Module.create(name, body, Macro.Env.location(__ENV__))
    Function.capture(name, :eval, 1)
  end

  # Builds an interpreted closure via Code.eval_quoted/3, matching
  # ExCellerate.compile_to_function/2. Its Function.info[:module] is :erl_eval.
  defp build_interpreted_fun(elixir_ast) do
    scope_var = Compiler.scope_var()
    fun_ast = {:fn, [], [{:->, [], [[scope_var], elixir_ast]}]}
    {fun, _} = Code.eval_quoted(fun_ast, [], __ENV__)
    fun
  end

  defp unique_module_name do
    Module.concat(ExCellerate.Compiled, "E#{:erlang.unique_integer([:positive])}")
  end
end
