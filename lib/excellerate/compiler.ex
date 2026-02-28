defmodule ExCellerate.Compiler do
  @moduledoc false
  # Internal: Transforms ExCellerate IR into Elixir AST.
  # This module is not intended to be used directly by library consumers.

  # Private sentinel for detecting missing keys in access expressions.
  # Using a unique tuple avoids collisions with legitimate user data.
  @not_found_sentinel {__MODULE__, :not_found}

  # The scope variable used in generated AST. Using a fixed Macro.var
  # ensures the fn wrapper in ExCellerate.compile/2 can bind to it.
  @scope_var Macro.var(:scope, __MODULE__)

  @doc false
  def scope_var, do: @scope_var

  # Dispatches a function call at runtime. Called from generated AST to
  # keep the quoted expression simple and reduce cyclomatic complexity.
  # Only module-based functions (registered via Registry or defaults) are
  # supported. Scope functions are not allowed — use a custom Registry instead.
  @doc false
  def dispatch_call(module, args) when is_atom(module) and module != nil do
    invoke_module(module, args)
  end

  def dispatch_call(other, _args) do
    raise ExCellerate.Error,
      message: "not a function: #{inspect(other)}",
      type: :runtime
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
                    message: "function '#{module.name()}' failed: #{Exception.message(e)}",
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

  # Called from generated AST to access struct fields.
  # Structs don't implement Access, so we convert the key to an
  # existing atom and use Map.get.
  @doc false
  def struct_get(struct, key, default) when is_binary(key) do
    try do
      Map.get(struct, String.to_existing_atom(key), default)
    rescue
      ArgumentError -> default
    end
  end

  def struct_get(struct, key, default) when is_atom(key) do
    Map.get(struct, key, default)
  end

  def struct_get(_struct, _key, default), do: default

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

  # Transform our custom IR to Elixir AST
  # Handles variable lookups from scope only. Functions are resolved at
  # compile time in the :call handler, not here.
  defp to_elixir_ast({:get_var, name}, _registry) do
    scope_var = @scope_var

    quote do
      case ExCellerate.Compiler.fetch_from_scope(unquote(scope_var), unquote(name)) do
        {:ok, val} ->
          val

        :error ->
          raise ExCellerate.Error,
            message: "variable not found: #{unquote(name)}",
            type: :runtime
      end
    end
  end

  defp to_elixir_ast({:access, target, key_or_index}, registry) do
    target_ast = to_elixir_ast(target, registry)
    key_ast = to_elixir_ast(key_or_index, registry)
    target_var = Macro.unique_var(:target, __MODULE__)
    key_var = Macro.unique_var(:key, __MODULE__)
    sentinel_var = Macro.unique_var(:sentinel, __MODULE__)

    quote do
      unquote(target_var) = unquote(target_ast)
      unquote(key_var) = unquote(key_ast)
      unquote(sentinel_var) = unquote(Macro.escape(@not_found_sentinel))

      case unquote(target_var) do
        list when is_list(list) and is_integer(unquote(key_var)) ->
          Enum.at(list, unquote(key_var), unquote(sentinel_var))

        %{__struct__: _} = struct ->
          # Structs don't implement Access; use Map.get with atom key.
          ExCellerate.Compiler.struct_get(
            struct,
            unquote(key_var),
            unquote(sentinel_var)
          )

        _ ->
          Access.get(unquote(target_var), unquote(key_var), unquote(sentinel_var))
      end
      |> case do
        ^unquote(sentinel_var) ->
          raise ExCellerate.Error,
            message: "Access failed: key not found",
            type: :runtime

        val ->
          val
      end
    end
  end

  defp to_elixir_ast({spread_type, target, expr}, registry)
       when spread_type in [:computed_spread, :flat_computed_spread] do
    target_ast = to_elixir_ast(target, registry)
    list_var = Macro.unique_var(:spread_list, __MODULE__)
    item_var = Macro.unique_var(:spread_item, __MODULE__)

    # Compile the inner expression. It references variables via :get_var,
    # which normally looks them up in @scope_var. We need each element to
    # be the scope for the inner expression, so we bind @scope_var to the
    # current item inside the mapping function.
    scope_var = @scope_var
    inner_ast = to_elixir_ast(expr, registry)

    spread_fn =
      case spread_type do
        :computed_spread -> :spread
        :flat_computed_spread -> :flat_spread
      end

    quote do
      unquote(list_var) = unquote(target_ast)

      ExCellerate.Compiler.unquote(spread_fn)(
        unquote(list_var),
        fn unquote(item_var) ->
          unquote(scope_var) = unquote(item_var)
          unquote(inner_ast)
        end
      )
    end
  end

  defp to_elixir_ast({spread_type, target, path}, registry)
       when spread_type in [:spread, :flat_spread] do
    target_ast = to_elixir_ast(target, registry)
    list_var = Macro.unique_var(:spread_list, __MODULE__)
    item_var = Macro.unique_var(:spread_item, __MODULE__)

    # Build the accessor chain that runs on each item.
    body_ast = build_spread_body(item_var, path, registry)

    spread_fn =
      case spread_type do
        :spread -> :spread
        :flat_spread -> :flat_spread
      end

    quote do
      unquote(list_var) = unquote(target_ast)

      ExCellerate.Compiler.unquote(spread_fn)(
        unquote(list_var),
        fn unquote(item_var) -> unquote(body_ast) end
      )
    end
  end

  # Called from generated AST to map over a list for [*] spread.
  @doc false
  def spread(list, fun) when is_list(list) do
    Enum.map(list, fun)
  end

  def spread(value, _fun) do
    raise ExCellerate.Error,
      message: "spread [*] requires a list, got #{inspect(value)}",
      type: :runtime
  end

  # Called from generated AST for nested [*] — flattens the input
  # (which is a list of lists from the previous spread), then maps
  # the function over each element.
  @doc false
  def flat_spread(list, fun) when is_list(list) do
    list
    |> List.flatten()
    |> Enum.map(fun)
  end

  def flat_spread(value, _fun) do
    raise ExCellerate.Error,
      message: "spread [*] requires a list, got #{inspect(value)}",
      type: :runtime
  end

  # Builds the AST that accesses nested fields within each spread item.
  defp build_spread_body(item_var, [], _registry), do: item_var

  defp build_spread_body(item_var, [{:key, key} | rest], registry) do
    access_ast =
      quote do
        ExCellerate.Compiler.spread_access(unquote(item_var), unquote(key))
      end

    build_spread_body(access_ast, rest, registry)
  end

  defp build_spread_body(item_var, [{:index, index_expr} | rest], registry) do
    index_ast = to_elixir_ast(index_expr, registry)

    access_ast =
      quote do
        ExCellerate.Compiler.spread_access(unquote(item_var), unquote(index_ast))
      end

    build_spread_body(access_ast, rest, registry)
  end

  # Called from generated AST to access a field/index on a spread item.
  # Handles maps (string and atom keys), structs, and list indexing.
  @doc false
  def spread_access(target, key) when is_map(target) and is_binary(key) do
    case Map.fetch(target, key) do
      {:ok, val} ->
        val

      :error ->
        try do
          case Map.fetch(target, String.to_existing_atom(key)) do
            {:ok, val} -> val
            :error -> nil
          end
        rescue
          ArgumentError -> nil
        end
    end
  end

  def spread_access(target, index) when is_list(target) and is_integer(index) do
    Enum.at(target, index)
  end

  def spread_access(target, key) when is_map(target) and is_atom(key) do
    Map.get(target, key)
  end

  def spread_access(_, _), do: nil

  defp to_elixir_ast({:call, target, args}, registry) do
    # Function calls are resolved strictly at compile time.
    # The function must exist in the registry or defaults — scope functions
    # are not supported. Use a custom Registry to add functions.

    args_list = List.wrap(args)

    # Resolve function module at compile time and validate arity.
    module =
      case target do
        {:get_var, name} ->
          case resolve_module_at_compile_time(name, registry) do
            nil ->
              raise ExCellerate.Error,
                message: "unknown function: #{name}",
                type: :compiler

            module ->
              validate_arity!(name, module, length(args_list))
              module
          end

        _ ->
          nil
      end

    # Recursively transform each argument into Elixir AST
    args_ast = Enum.map(args_list, fn arg -> to_elixir_ast(arg, registry) end)
    args_var = Macro.unique_var(:actual_args, __MODULE__)

    target_ast =
      if module do
        # Resolved at compile time — embed the module directly.
        module
      else
        to_elixir_ast(target, registry)
      end

    quote do
      unquote(args_var) = [unquote_splicing(args_ast)]
      ExCellerate.Compiler.dispatch_call(unquote(target_ast), unquote(args_var))
    end
  end

  defp to_elixir_ast({op, meta, [left, right]}, registry)
       when op in [
              :+,
              :-,
              :*,
              :/,
              :%,
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
      :% -> quote do: rem(unquote(left_ast), unquote(right_ast))
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
