defmodule ExCellerate do
  alias ExCellerate.Parser
  import Bitwise

  @doc """
  Evaluates a text expression.
  """
  def eval(expression, scope \\ %{}) do
    case Parser.parse(expression) do
      {:ok, ast} ->
        try do
          elixir_ast = to_elixir_ast(ast)
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

  # Transform our custom IR to Elixir AST
  defp to_elixir_ast({:get_var, name}) do
    quote do
      case Map.fetch(var!(scope), unquote(name)) do
        {:ok, val} -> val
        :error -> raise "not_found"
      end
    end
  end

  defp to_elixir_ast({:access, target, key_or_index}) do
    target_ast = to_elixir_ast(target)
    key_ast = to_elixir_ast(key_or_index)

    quote do
      target = unquote(target_ast)
      key = unquote(key_ast)

      case target do
        list when is_list(list) and is_integer(key) ->
          Enum.at(list, key, :not_found)

        _ ->
          Access.get(target, key, :not_found)
      end
      |> case do
        :not_found ->
          raise "not_found"

        val ->
          val
      end
    end
  end

  defp to_elixir_ast({op, meta, [left, right]})
       when op in [
              :+,
              :-,
              :*,
              :/,
              :^,
              :==,
              :!=,
              :>,
              :>=,
              :<,
              :<=,
              :&&,
              :||,
              :<<<,
              :>>>,
              :&&&,
              :|||,
              :"^^^"
            ] do
    left_ast = to_elixir_ast(left)
    right_ast = to_elixir_ast(right)

    case op do
      :^ -> quote do: :math.pow(unquote(left_ast), unquote(right_ast)) |> round()
      _ -> {op, meta, [left_ast, right_ast]}
    end
  end

  defp to_elixir_ast({:not, meta, [operand]}) do
    {:not, meta, [to_elixir_ast(operand)]}
  end

  defp to_elixir_ast({:bnot, meta, [operand]}) do
    {:"~~~", meta, [to_elixir_ast(operand)]}
  end

  defp to_elixir_ast({:factorial, _meta, [operand]}) do
    operand_ast = to_elixir_ast(operand)
    quote do: ExCellerate.Math.factorial(unquote(operand_ast))
  end

  defp to_elixir_ast({:ternary, _meta, [cond, true_val, false_val]}) do
    quote do
      if unquote(to_elixir_ast(cond)) do
        unquote(to_elixir_ast(true_val))
      else
        unquote(to_elixir_ast(false_val))
      end
    end
  end

  defp to_elixir_ast({:negate, meta, [operand]}) do
    {:-, meta, [to_elixir_ast(operand)]}
  end

  defp to_elixir_ast(literal), do: literal
end
