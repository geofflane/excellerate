defmodule ExCellerate.NativeCompiler do
  @moduledoc false
  # Internal: compiles an expression into a real BEAM module so evaluation runs
  # compiled code rather than the :erl_eval interpreter that Code.eval_quoted
  # produces. Phase 1: standalone helper for benchmarking. No caching here.

  alias ExCellerate.{Compiler, Parser}

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

  defp build_module_fun(ast, registry) do
    elixir_ast = Compiler.compile(ast, registry)
    scope_var = Compiler.scope_var()
    mod_name = unique_module_name()

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

    Module.create(mod_name, body, Macro.Env.location(__ENV__))
    Function.capture(mod_name, :eval, 1)
  end

  defp unique_module_name do
    Module.concat(ExCellerate.Compiled, "E#{:erlang.unique_integer([:positive])}")
  end
end
