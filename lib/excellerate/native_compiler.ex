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
    cap =
      Keyword.get(
        opts,
        :native_module_limit,
        Application.get_env(:excellerate, :native_module_limit, @default_module_limit)
      )

    {:ok, %{slots: Slots.new(cap), by_key: %{}}}
  end

  # Compiles `elixir_ast` into a native BEAM module, reusing a pooled module
  # name. Dedups by {registry, expr}. Returns:
  #
  #   * {:ok, fun, mod_name}      — native module function
  #   * {:ok, interpreted_fun, nil} — fallback when the pool is full
  @spec compile_cached(module() | nil, String.t(), Macro.t()) ::
          {:ok, (ExCellerate.scope() -> any()), module() | nil}
  def compile_cached(registry, expr, elixir_ast) do
    GenServer.call(__MODULE__, {:compile, registry, expr, elixir_ast})
  end

  @impl true
  def handle_call({:compile, registry, expr, elixir_ast}, _from, state) do
    key = {registry, expr}

    case Map.get(state.by_key, key) do
      nil ->
        case Slots.alloc(state.slots) do
          {:ok, name, slots} ->
            fun = create_eval_module(name, elixir_ast)
            by_key = Map.put(state.by_key, key, name)
            {:reply, {:ok, fun, name}, %{state | slots: slots, by_key: by_key}}

          {:full, slots} ->
            {:reply, {:ok, build_interpreted_fun(elixir_ast), nil}, %{state | slots: slots}}
        end

      mod ->
        {:reply, {:ok, Function.capture(mod, :eval, 1), mod}, state}
    end
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
