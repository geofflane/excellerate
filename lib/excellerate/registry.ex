defmodule ExCellerate.Registry do
  @moduledoc """
  Provides functionality for creating custom function registries.

  Registries allow you to define a set of custom functions (plugins) that
  extend the built-in capabilities of ExCellerate.

  ## Usage

  Define a registry module and use `ExCellerate.Registry`:

      defmodule MyRegistry do
        use ExCellerate.Registry, plugins: [
          MyApp.Functions.Greet,
          MyApp.Functions.CustomMath
        ]
      end

  Then use it in `ExCellerate.eval!/3` or call the generated `eval!/2` directly:

      # Using the registry in eval!/3
      ExCellerate.eval!("greet(name)", %{"name" => "World"}, MyRegistry)

      # Using the generated helper
      MyRegistry.eval!("greet('World')")

  ## Resolution Order

  Functions are resolved at compile time in the following order:
  1. Registry plugins
  2. Default built-in functions

  If a function name cannot be resolved, a compiler error is raised.
  Variables in the scope are only used for data access, not function calls.
  """

  @doc false
  # Internal: Injects the registry logic and an eval/2 helper into the module.
  defmacro __using__(opts) do
    plugins = Keyword.get(opts, :plugins, [])
    cache_enabled = Keyword.get(opts, :cache_enabled, true)
    cache_limit = Keyword.get(opts, :cache_limit, 1000)

    quote do
      @plugins unquote(plugins)
      @cache_enabled unquote(cache_enabled)
      @cache_limit unquote(cache_limit)
      @before_compile ExCellerate.Registry

      @doc """
      Evaluates an expression using this registry.

      Returns `{:ok, result}` on success or `{:error, reason}` on failure.
      See `eval!/2` for a version that returns the bare result or raises.
      """
      @spec eval(String.t(), ExCellerate.scope()) :: {:ok, any()} | {:error, Exception.t()}
      def eval(expression, scope \\ %{}) do
        ExCellerate.eval(expression, scope, __MODULE__)
      end

      @doc """
      Evaluates an expression using this registry, returning the bare result or raising on error.
      """
      @spec eval!(String.t(), ExCellerate.scope()) :: any()
      def eval!(expression, scope \\ %{}) do
        ExCellerate.eval!(expression, scope, __MODULE__)
      end

      @doc """
      Internal: Configuration for ExCellerate.
      """
      def __excellerate_config__(:cache_enabled), do: @cache_enabled
      def __excellerate_config__(:cache_limit), do: @cache_limit
    end
  end

  @doc false
  # Internal: Generates the `resolve_function/1` clauses at compile-time.
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
