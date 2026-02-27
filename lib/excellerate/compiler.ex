defmodule ExCellerate.Compiler do
  @moduledoc false
  # Internal: Transforms ExCellerate IR into Elixir AST.
  # This module is not intended to be used directly by library consumers.

  # Dispatches a function call at runtime. Called from generated AST to
  # keep the quoted expression simple and reduce cyclomatic complexity.
  @doc false
  def dispatch_call(func, args) do
    case func do
      f when is_function(f) ->
        validate_function_arity!(f, args)
        apply(f, args)

      module when is_atom(module) and module != nil ->
        invoke_module(module, args)

      _ ->
        raise ExCellerate.Error,
          message: "not a function: #{inspect(func)}",
          type: :runtime
    end
  end

  defp validate_function_arity!(func, args) do
    {:arity, expected} = :erlang.fun_info(func, :arity)
    actual = length(args)

    unless expected == actual do
      raise ExCellerate.Error,
        message: "wrong arity: function expects #{expected} argument(s), got #{actual}",
        type: :runtime
    end
  end

  defp invoke_module(module, args) do
    # TODO: Is there a way to do this once instead of every call?
    if Code.ensure_loaded?(module) and function_exported?(module, :call, 1) do
      validate_module_arity!(module, args)

      try do
        module.call(args)
      rescue
        e in ExCellerate.Error ->
          reraise e, __STACKTRACE__

        e ->
          reraise ExCellerate.Error,
                  [
                    message:
                      "function '#{inspect(module.name())}' failed: #{Exception.message(e)}",
                    type: :runtime,
                    details: e
                  ],
                  __STACKTRACE__
      end
    else
      raise ExCellerate.Error,
        message: "not a function: #{inspect(module)}",
        type: :runtime
    end
  end

  defp validate_module_arity!(module, args) when is_atom(module) and is_list(args) do
    if function_exported?(module, :arity, 0), do: do_validate_module_arity!(module, args)
  end

  defp do_validate_module_arity!(module, args) do
    expected = module.arity()
    actual = length(args)

    if expected == :any or expected == actual do
      :ok
    else
      name = if function_exported?(module, :name, 0), do: module.name(), else: inspect(module)

      raise ExCellerate.Error,
        message: "wrong number of arguments for '#{name}': expected #{expected}, got #{actual}",
        type: :runtime
    end
  end

  # Called from generated AST to resolve scope variables.
  # Tries string key first, then atom key (if the atom already exists).
  @doc false
  def fetch_from_scope(scope, name) when is_map(scope) and is_binary(name) do
    case Map.fetch(scope, name) do
      {:ok, _} = hit ->
        hit

      :error ->
        try do
          Map.fetch(scope, String.to_existing_atom(name))
        rescue
          ArgumentError -> :error
        end
    end
  end

  # Compiles the IR into Elixir AST.
  @spec compile(tuple() | any(), module() | nil) :: Macro.t()
  def compile(ast, registry \\ nil) do
    to_elixir_ast(ast, registry)
  end

  # Resolves a function module at compile-time (during Compiler.compile/2).
  # Returns the module if found, nil otherwise. Used for compile-time arity checks.
  defp resolve_module_at_compile_time(name, nil) do
    ExCellerate.Functions.get_default_function(name)
  end

  defp resolve_module_at_compile_time(name, registry) do
    if Code.ensure_loaded?(registry) and function_exported?(registry, :resolve_function, 1) do
      case registry.resolve_function(name) do
        {:ok, module} -> module
        :error -> nil
      end
    else
      nil
    end
  end

  # Validates that the number of arguments matches the function's declared arity.
  # Raises ExCellerate.Error with type :compiler on mismatch.
  # Skips check for :any arity (variadic functions).
  defp validate_arity!(name, module, arg_count) do
    expected = module.arity()

    unless expected == :any or expected == arg_count do
      raise ExCellerate.Error,
        message:
          "wrong number of arguments for '#{name}': expected #{expected}, got #{arg_count}",
        type: :compiler
    end
  end

  # Resolves a function name from the registry or defaults.
  # Returns a quote block that resolves to a module or :not_found at runtime.
  defp resolve_from_registry(name, nil) do
    quote do
      case ExCellerate.Functions.get_default_function(unquote(name)) do
        nil ->
          raise ExCellerate.Error,
            message: "Function or variable not found: #{unquote(name)}",
            type: :runtime

        module ->
          module
      end
    end
  end

  defp resolve_from_registry(name, registry) do
    quote do
      case unquote(registry).resolve_function(unquote(name)) do
        {:ok, module} ->
          module

        :error ->
          raise ExCellerate.Error,
            message: "Function or variable not found: #{unquote(name)}",
            type: :runtime
      end
    end
  end

  # Transform our custom IR to Elixir AST
  # Handles variable lookups and function resolution from scope/registry.
  defp to_elixir_ast({:get_var, name}, registry) do
    quote do
      case ExCellerate.Compiler.fetch_from_scope(var!(scope), unquote(name)) do
        {:ok, val} ->
          val

        :error ->
          # Check registry if provided
          unquote(resolve_from_registry(name, registry))
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
          raise ExCellerate.Error,
            message: "Access failed: key not found",
            type: :runtime

        val ->
          val
      end
    end
  end

  defp to_elixir_ast({:call, target, args}, registry) do
    # For :call, we want to try resolving the target as a function/module
    # BUT we need to handle the case where it's a raw variable name that
    # might be in the registry but not the scope.

    # args must be a list of AST nodes
    args_list = List.wrap(args)

    # Compile-time arity check: if target is a named function and we can
    # resolve it to a module, validate arity now (before generating AST).
    case target do
      {:get_var, name} ->
        case resolve_module_at_compile_time(name, registry) do
          nil -> :ok
          module -> validate_arity!(name, module, length(args_list))
        end

      _ ->
        :ok
    end

    target_ast =
      case target do
        {:get_var, name} ->
          quote do
            case Map.fetch(var!(scope), unquote(name)) do
              {:ok, val} when is_function(val) -> val
              _ -> unquote(resolve_from_registry(name, registry))
            end
          end

        _ ->
          to_elixir_ast(target, registry)
      end

    # Recursively transform each argument into Elixir AST
    args_ast = Enum.map(args_list, fn arg -> to_elixir_ast(arg, registry) end)

    quote do
      func = unquote(target_ast)
      # evaluate all arguments - this should be a list of values at runtime
      # Using unquote_splicing inside [] ensures we get a list of values.
      actual_args = [unquote_splicing(args_ast)]

      ExCellerate.Compiler.dispatch_call(func, actual_args)
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
      :^ -> quote do: :math.pow(unquote(left_ast), unquote(right_ast))
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
