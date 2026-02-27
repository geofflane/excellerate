defmodule ExCellerate do
  @moduledoc """
  ExCellerate is a high-performance expression evaluation engine for Elixir.

  It parses text expressions into an intermediate representation (IR) and then
  compiles them into native Elixir AST for near-native performance.

  ## Features

  - Arithmetic operators: `+`, `-`, `*`, `/`, `^`, `%`
  - Comparison operators: `==`, `!=`, `<`, `<=`, `>`, `>=`
  - Logical operators: `&&`, `||`, `!` (not)
  - Bitwise operators: `&&&`, `|||`, `^^^`, `<<<`, `>>>`, `~~~` (bnot)
  - Ternary operator: `condition ? true_val : false_val`
  - Factorial: `n!`
  - Nested data access: `user.profile.name` or `list.0`
  - Custom functions via a Registry system.

  ## Examples

      iex> ExCellerate.eval!("1 + 2 * 3")
      7

      iex> ExCellerate.eval("a + b", %{"a" => 10, "b" => 20})
      {:ok, 30}

      iex> ExCellerate.eval!("user.name", %{"user" => %{"name" => "Alice"}})
      "Alice"
  """

  alias ExCellerate.Compiler
  alias ExCellerate.Parser

  @type scope :: %{optional(String.t()) => any()}
  @type registry :: module() | nil

  @doc """
  Evaluates a text expression against an optional scope and registry.

  Returns `{:ok, result}` on success or `{:error, reason}` on failure.
  See `eval!/3` for a version that returns the bare result or raises.

  ## Parameters

  - `expression`: A string containing the ExCellerate expression.
  - `scope`: A map of variables available to the expression. Defaults to `%{}`.
  - `registry`: An optional module that implements the ExCellerate.Registry behaviour.

  ## Examples

      iex> ExCellerate.eval("1 + 2 * 3")
      {:ok, 7}

      iex> ExCellerate.eval("a + b", %{"a" => 10, "b" => 20})
      {:ok, 30}

      iex> ExCellerate.eval("user.name", %{"user" => %{"name" => "Alice"}})
      {:ok, "Alice"}

      iex> {:error, _} = ExCellerate.eval("1 + * 2")

  """
  @spec eval(String.t(), scope(), registry()) :: {:ok, any()} | {:error, Exception.t()}
  def eval(expression, scope \\ %{}, registry \\ nil) do
    case compile(expression, registry) do
      {:ok, fun} ->
        try do
          {:ok, fun.(scope)}
        rescue
          e -> {:error, e}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Evaluates a text expression, returning the bare result or raising on error.

  This is the "bang" variant of `eval/3`. It returns the result directly
  on success, or raises the error as an exception on failure.

  ## Parameters

  - `expression`: A string containing the ExCellerate expression.
  - `scope`: A map of variables available to the expression. Defaults to `%{}`.
  - `registry`: An optional module that implements the ExCellerate.Registry behaviour.

  ## Supported Operators

  - **Arithmetic**: `+`, `-`, `*`, `/`, `^` (power), `%` (modulo), `n!` (factorial)
  - **Comparison**: `==`, `!=`, `<`, `<=`, `>`, `>=`
  - **Logical**: `&&`, `||`, `!`, `not`
  - **Bitwise**: `&&&`, `|||`, `^^^`, `<<<`, `>>>`, `~~~` (bnot)
  - **Ternary**: `condition ? true_val : false_val`

  ## Built-in Functions

  - **Math**: `abs(n)`, `round(n)`, `floor(n)`, `ceil(n)`, `max(a, b)`, `min(a, b)`
  - **Utility**: `if(cond, t, f)`, `ifnull(val, default)`, `lookup(coll, key, default \\ nil)`
  - **String**: `concat(a, b, ...)`, `normalize(s)`, `substring(s, start, len \\ nil)`, `contains(s, term)`

  ## Examples

      iex> ExCellerate.eval!("1 + 2 * 3")
      7

      iex> ExCellerate.eval!("5!")
      120

      iex> ExCellerate.eval!("a > 10 ? 'high' : 'low'", %{"a" => 15})
      "high"

      iex> ExCellerate.eval!("concat('Hello', ' ', name)", %{"name" => "Alice"})
      "Hello Alice"

      iex> ExCellerate.eval!("user.profile.id", %{"user" => %{"profile" => %{"id" => 1}}})
      1

  ## Raises

  - `ExCellerate.Error` if parsing or compilation fails.
  - Any exception raised during evaluation.
  """
  @spec eval!(String.t(), scope(), registry()) :: any()
  def eval!(expression, scope \\ %{}, registry \\ nil) do
    case eval(expression, scope, registry) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  @doc """
  Compiles an expression into a reusable function.

  Returns `{:ok, fun}` where `fun` is a 1-arity function that accepts a
  scope map and returns the result. The compiled function is cached, so
  calling `compile/2` repeatedly with the same expression is cheap.

  This is useful when you need to evaluate the same expression many times
  with different scopes — the parsing and compilation happen only once.

  ## Examples

      iex> {:ok, fun} = ExCellerate.compile("a + b")
      iex> fun.(%{"a" => 1, "b" => 2})
      3

  """
  @spec compile(String.t(), registry()) ::
          {:ok, (scope() -> any())} | {:error, ExCellerate.Error.t()}
  def compile(expression, registry \\ nil) do
    case ExCellerate.Cache.get(registry, expression) do
      {:ok, fun} ->
        {:ok, fun}

      :error ->
        case compile_to_function(expression, registry) do
          {:ok, fun} ->
            ExCellerate.Cache.put(registry, expression, fun)
            {:ok, fun}

          {:error, _} = error ->
            error
        end
    end
  end

  @doc """
  Compiles an expression into a reusable function, raising on error.

  Returns the compiled function directly, or raises `ExCellerate.Error`
  if the expression is invalid.

  ## Examples

      iex> fun = ExCellerate.compile!("x * 2")
      iex> fun.(%{"x" => 5})
      10

  """
  @spec compile!(String.t(), registry()) :: (scope() -> any())
  def compile!(expression, registry \\ nil) do
    case compile(expression, registry) do
      {:ok, fun} -> fun
      {:error, error} -> raise error
    end
  end

  @doc """
  Validates that an expression is syntactically correct and all referenced functions exist.
  """
  @spec validate(String.t(), registry()) :: :ok | {:error, ExCellerate.Error.t()}
  def validate(expression, registry \\ nil) do
    case compile(expression, registry) do
      {:ok, _fun} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # Parses and compiles an expression string into a reusable function.
  # The function accepts a scope map and returns the evaluation result.
  # The scope parameter must use var!(scope) in the Compiler context
  # to match the references generated by Compiler.compile/2.
  defp compile_to_function(expression, registry) do
    case Parser.parse(expression) do
      {:ok, ast} ->
        try do
          elixir_ast = Compiler.compile(ast, registry)
          scope_var = Compiler.scope_var()

          fun_ast =
            {:fn, [], [{:->, [], [[scope_var], elixir_ast]}]}

          {fun, _} = Code.eval_quoted(fun_ast, [], __ENV__)
          {:ok, fun}
        rescue
          e -> {:error, e}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
