defmodule ExCellerate.Compilation.Interpreted do
  @moduledoc """
  Compilation strategy that evaluates expressions via an interpreted
  `Code.eval_quoted/3` closure.

  No BEAM module is created, so it consumes no atoms per expression — the right
  choice for unbounded or untrusted expression input. This is ExCellerate's
  original execution path. Slower per call than `ExCellerate.Compilation.NativeCompiled`,
  but with no compile cost and no atom growth — which also makes it preferable for
  expressions evaluated only a few times, where native's one-time compile cost
  would not pay off.
  """
  @behaviour ExCellerate.Compilation.Strategy

  alias ExCellerate.Compiler

  @impl true
  def build(_registry, _expression, elixir_ast) do
    {build_fun(elixir_ast), nil}
  end

  @doc false
  # Builds the interpreted closure. Pure (no process required) and shared by
  # other strategies as their fallback (e.g. NativeCompiled when its compiler is
  # unavailable). `Function.info(fun)[:module]` is `:erl_eval`.
  def build_fun(elixir_ast) do
    scope_var = Compiler.scope_var()
    fun_ast = {:fn, [], [{:->, [], [[scope_var], elixir_ast]}]}
    {fun, _} = Code.eval_quoted(fun_ast, [], __ENV__)
    fun
  end
end
