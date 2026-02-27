defmodule ExCellerate.Compiler do
  @moduledoc """
  Transforms ExCellerate IR into Elixir AST.
  """
  import Bitwise

  def compile(ast, registry \\ nil) do
    to_elixir_ast(ast, registry)
  end

  defp resolve_from_registry(name, nil) do
    quote do
      ExCellerate.Functions.get_default_function(unquote(name)) || :not_found
    end
  end

  defp resolve_from_registry(name, registry) do
    quote do
      case unquote(registry).resolve_function(unquote(name)) do
        {:ok, module} -> module
        :error -> :not_found
      end
    end
  end

  # Transform our custom IR to Elixir AST
  defp to_elixir_ast({:get_var, name}, registry) do
    quote do
      case Map.fetch(var!(scope), unquote(name)) do
        {:ok, val} ->
          val

        :error ->
          # Check registry if provided
          case unquote(resolve_from_registry(name, registry)) do
            :not_found -> raise "not_found"
            module -> module
          end
      end
    end
  end

  defp to_elixir_ast({:access, target, key_or_index}, registry) do
    target_ast = to_elixir_ast(target, registry)
    key_ast = to_elixir_ast(key_or_index, registry)

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

  defp to_elixir_ast({:call, target, args}, registry) do
    target_ast = to_elixir_ast(target, registry)
    # args must be a list of AST nodes
    args_list = List.wrap(args)
    # Recursively transform each argument into Elixir AST
    args_ast = Enum.map(args_list, fn arg -> to_elixir_ast(arg, registry) end)

    quote do
      func = unquote(target_ast)
      # evaluate all arguments - this should be a list of values at runtime
      # Using unquote_splicing inside [] ensures we get a list of values.
      actual_args = [unquote_splicing(args_ast)]

      case func do
        f when is_function(f) ->
          apply(f, actual_args)

        module when is_atom(module) and module != nil ->
          if function_exported?(module, :call, 1) do
            # Use call directly with the list of arguments
            module.call(actual_args)
          else
            raise "not a function: #{inspect(module)}"
          end

        _ ->
          raise "not a function: #{inspect(func)}"
      end
    end
  end

  defp to_elixir_ast({op, meta, [left, right]}, registry)
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
    left_ast = to_elixir_ast(left, registry)
    right_ast = to_elixir_ast(right, registry)

    case op do
      :^ -> quote do: :math.pow(unquote(left_ast), unquote(right_ast)) |> round()
      :<<< -> quote do: Bitwise.<<<(unquote(left_ast), unquote(right_ast))
      :>>> -> quote do: Bitwise.>>>(unquote(left_ast), unquote(right_ast))
      :&&& -> quote do: Bitwise.&&&(unquote(left_ast), unquote(right_ast))
      :||| -> quote do: Bitwise.|||(unquote(left_ast), unquote(right_ast))
      :"^^^" -> quote do: Bitwise.^^^(unquote(left_ast), unquote(right_ast))
      _ -> {op, meta, [left_ast, right_ast]}
    end
  end

  defp to_elixir_ast({:not, meta, [operand]}, registry) do
    {:not, meta, [to_elixir_ast(operand, registry)]}
  end

  defp to_elixir_ast({:bnot, _meta, [operand]}, registry) do
    operand_ast = to_elixir_ast(operand, registry)
    quote do: Bitwise.~~~(unquote(operand_ast))
  end

  defp to_elixir_ast({:factorial, _meta, [operand]}, registry) do
    operand_ast = to_elixir_ast(operand, registry)
    quote do: ExCellerate.Math.factorial(unquote(operand_ast))
  end

  defp to_elixir_ast({:ternary, _meta, [cond, true_val, false_val]}, registry) do
    quote do
      if unquote(to_elixir_ast(cond, registry)) do
        unquote(to_elixir_ast(true_val, registry))
      else
        unquote(to_elixir_ast(false_val, registry))
      end
    end
  end

  defp to_elixir_ast({:negate, meta, [operand]}, registry) do
    {:-, meta, [to_elixir_ast(operand, registry)]}
  end

  defp to_elixir_ast(literal, _registry), do: literal
end
