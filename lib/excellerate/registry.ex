defmodule ExCellerate.Registry do
  @moduledoc """
  Provides functionality for creating custom registries with plugins.
  """

  defmacro __using__(opts) do
    plugins = Keyword.get(opts, :plugins, [])

    quote do
      @plugins unquote(plugins)
      @before_compile ExCellerate.Registry

      def eval(expression, scope \\ %{}) do
        ExCellerate.eval(expression, scope, __MODULE__)
      end
    end
  end

  defmacro __before_compile__(env) do
    plugins = Module.get_attribute(env.module, :plugins)
    default_functions = ExCellerate.Functions.list_defaults()

    # Build a combined list of functions, where plugins override defaults if names match.
    # We use a map to handle deduplication by name.
    all_functions_map =
      (default_functions ++ plugins)
      |> Enum.reduce(%{}, fn mod, acc ->
        Map.put(acc, mod.name(), mod)
      end)

    clauses =
      for {name, mod} <- all_functions_map do
        quote do
          def resolve_function(unquote(name)), do: {:ok, unquote(mod)}
        end
      end

    quote do
      unquote(clauses)
      def resolve_function(_), do: :error
    end
  end
end
