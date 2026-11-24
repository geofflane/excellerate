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
  #     serializes module creation. `compile_cached/4` dedups by {registry, expr}
  #     and falls back to an interpreted closure when the pool is exhausted.
  #     Pooled names are reused, so callers get a generation-checked closure
  #     rather than a bare module capture (see "Stale-slot guard" below).
  #
  # This module manages modules and names only. How a stale closure recovers
  # (recompiling through the cache) is supplied by the caller, so the pool does
  # not depend on ExCellerate's compile pipeline that depends on it.

  use GenServer

  alias ExCellerate.Compilation.Interpreted
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

    # A restart starts with an empty pool, so it is about to reuse names from
    # pooled modules a killed predecessor left loaded (terminate/2 doesn't run on
    # :kill). Unload them first, so reusing a name never redefines a loaded module.
    unload_leftover_modules()

    # Caller-supplied hook, run on every (re)start. The supervisor passes one that
    # drops cached native funs: the modules they point at belong to the previous
    # server. Supplied as an MFA so this module doesn't depend on the Cache that
    # depends on it.
    case Keyword.get(opts, :on_init) do
      {m, f, a} -> apply(m, f, a)
      nil -> :ok
    end

    {:ok, %{slots: Slots.new(cap), by_key: %{}, grace_ms: grace_ms, warned_full: false}}
  end

  defp unload_leftover_modules do
    for {mod, _} <- :code.all_loaded(), Slots.pooled_name?(mod) do
      # Drop any old version first, so :code.delete has nothing to complain about,
      # then make the current version old and purge it. soft_purge leaves code a
      # process is still running; that process finishes on the old version.
      :code.soft_purge(mod)
      :code.delete(mod)
      :code.soft_purge(mod)
    end

    :ok
  end

  # Compiles `elixir_ast` into a native BEAM module, reusing a pooled module
  # name. Dedups by {registry, expr}. Returns:
  #
  #   * {:ok, fun, mod_name}      — native module function
  #   * {:ok, interpreted_fun, nil} — fallback when the pool is full
  #
  # `on_stale.(scope, stale_mod)` evaluates the expression for a scope when the
  # returned closure finds its slot released (see "Stale-slot guard" below).
  # `stale_mod` is the module the closure was bound to, so the caller can drop
  # cache entries that still point at it.
  #
  # Assumes `elixir_ast` is an already-parsed/compiled, valid AST (produced by
  # Parser + Compiler). Module creation is still guarded so a malformed-AST edge
  # case falls back to an interpreted closure instead of crashing the server.
  @spec compile_cached(
          module() | nil,
          String.t(),
          Macro.t(),
          (ExCellerate.scope(), module() -> any())
        ) :: {:ok, (ExCellerate.scope() -> any()), module() | nil}
  def compile_cached(registry, expr, elixir_ast, on_stale) do
    GenServer.call(__MODULE__, {:compile, registry, expr, elixir_ast, on_stale})
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
  def handle_call({:compile, registry, expr, elixir_ast, on_stale}, _from, state) do
    key = {registry, expr}

    case Map.get(state.by_key, key) do
      nil ->
        case Slots.alloc(state.slots) do
          {:ok, name, slots} ->
            try do
              gen = :erlang.unique_integer([:positive])
              create_eval_module(name, elixir_ast, gen)
              fun = guarded_fun(name, gen, on_stale)
              by_key = Map.put(state.by_key, key, {name, gen})
              {:reply, {:ok, fun, name}, %{state | slots: slots, by_key: by_key}}
            rescue
              _ ->
                # Module creation failed (e.g. a malformed AST). Return the slot
                # to the pool and fall back to an interpreted closure without
                # recording it in by_key.
                slots = Slots.free(slots, name)
                {:reply, {:ok, Interpreted.build_fun(elixir_ast), nil}, %{state | slots: slots}}
            end

          {:full, slots} ->
            state = maybe_warn_full(state)
            {:reply, {:ok, Interpreted.build_fun(elixir_ast), nil}, %{state | slots: slots}}
        end

      {mod, gen} ->
        {:reply, {:ok, guarded_fun(mod, gen, on_stale), mod}, state}
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

      {mod, _gen} ->
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

  # A full pool silently costs every new expression the native speedup, so make
  # it visible. Logged once per server lifetime (state, not :persistent_term, so
  # a restarted server — e.g. in tests — warns again).
  defp maybe_warn_full(%{warned_full: true} = state), do: state

  defp maybe_warn_full(state) do
    require Logger

    Logger.warning(
      "ExCellerate.NativeCompiler module pool is full " <>
        "(native_module_limit: #{state.slots.cap}); new expressions will be " <>
        "evaluated interpreted until cached entries are evicted. The pool is " <>
        "shared by every native registry, so size native_module_limit to at " <>
        "least the sum of their cache_limit values. This warning is logged once."
    )

    %{state | warned_full: true}
  end

  ## Shared helpers

  defp build_module_fun(ast, registry) do
    elixir_ast = Compiler.compile(ast, registry)
    name = unique_module_name()
    gen = :erlang.unique_integer([:positive])
    create_eval_module(name, elixir_ast, gen)
    # Standalone names are never reused, so no staleness guard is needed.
    fn scope -> name.eval(scope, gen) end
  end

  ## Stale-slot guard
  #
  # Pooled module names are reused once a slot is released and purged. A caller
  # may still hold the fun it got from compile/2, so a bare `&S0.eval/1` capture
  # would later run whatever expression next occupies S0 (or raise :undef while
  # the slot sits free). Instead, each module is compiled with a generation
  # number that only its own eval/2 clause accepts, and callers receive a closure
  # (defined here, in a module that is never purged) that detects a stale slot
  # and hands the scope to the caller-supplied `on_stale`.

  defp guarded_fun(mod, gen, on_stale) do
    fn scope -> run(mod, gen, on_stale, scope) end
  end

  @doc false
  def run(mod, gen, on_stale, scope) do
    mod.eval(scope, gen)
  catch
    :error, {:excellerate_stale_module, ^mod} ->
      on_stale.(scope, mod)

    :error, :undef ->
      # Only treat :undef as staleness when the missing function is this slot's
      # own eval/2 (module purged, slot not yet reused). An :undef raised from
      # inside the expression is a real error and is re-raised untouched.
      case __STACKTRACE__ do
        [{^mod, :eval, args, _} | _] when args == 2 or length(args) == 2 ->
          on_stale.(scope, mod)

        stacktrace ->
          :erlang.raise(:error, :undef, stacktrace)
      end
  end

  # Creates a module under `name` whose `eval(scope, gen)` evaluates
  # `elixir_ast` only when called with this module's own generation; any other
  # generation means the caller holds a fun for a previous occupant of the slot.
  defp create_eval_module(name, elixir_ast, gen) do
    scope_var = Compiler.scope_var()

    body =
      quote do
        def eval(unquote(scope_var), unquote(gen)) do
          # Mark the scope param used so scope-less expressions (e.g. "1 + 2")
          # do not emit an unused-variable warning at Module.create time. The
          # interpreted fn-wrapper path does not warn on unused args; match that.
          _ = unquote(scope_var)
          unquote(elixir_ast)
        end

        def eval(_scope, _gen), do: :erlang.error({:excellerate_stale_module, __MODULE__})
      end

    Module.create(name, body, Macro.Env.location(__ENV__))
    :ok
  end

  defp unique_module_name do
    Module.concat(ExCellerate.Compiled, "E#{:erlang.unique_integer([:positive])}")
  end
end
