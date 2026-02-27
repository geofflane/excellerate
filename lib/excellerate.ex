defmodule ExCellerate do
  alias ExCellerate.Parser
  alias ExCellerate.Compiler

  @doc """
  Evaluates a text expression.
  """
  def eval(expression, scope \\ %{}, registry \\ nil) do
    case Parser.parse(expression) do
      {:ok, ast} ->
        try do
          elixir_ast = Compiler.compile(ast, registry)
          {result, _} = Code.eval_quoted(elixir_ast, [scope: scope], __ENV__)
          result
        rescue
          e ->
            if is_map(e) and Map.get(e, :message) == "not_found" do
              {:error, :not_found}
            else
              {:error, e}
            end
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
