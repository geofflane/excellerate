defmodule ExCellerate do
  @moduledoc """
  ExCellerate is a high-performance expression evaluation engine for Elixir.

  It parses text expressions into an intermediate representation (IR) and then
  compiles them into native Elixir AST for near-native performance.

  ## Operators

  - **Arithmetic**: `+`, `-`, `*`, `/`, `^` (power), `%` (modulo), `n!` (factorial)
  - **Comparison**: `==`, `!=`, `<`, `<=`, `>`, `>=`
  - **Logical**: `&&`, `||`, `not`
  - **Bitwise**: `&`, `|`, `|^` (xor), `<<`, `>>`, `~` (bnot)
  - **Ternary**: `condition ? true_val : false_val`
  - **Data access**: `user.profile.name`, `list[0]`

  ## Built-in Functions

  ### Math

  | Function | Description |
  |----------|-------------|
  | `abs(n)` | Absolute value |
  | `round(n)` | Rounds to the nearest integer |
  | `floor(n)` | Largest integer ≤ `n` |
  | `ceil(n)` | Smallest integer ≥ `n` |
  | `trunc(n)` | Truncates toward zero (unlike `floor` for negatives) |
  | `max(a, b)` | Returns the larger value |
  | `min(a, b)` | Returns the smaller value |
  | `sign(n)` | Returns -1, 0, or 1 |
  | `sqrt(n)` | Square root |
  | `exp(n)` | e raised to the power `n` |
  | `ln(n)` | Natural logarithm (base e) |
  | `log(n, base)` | Logarithm with specified base |
  | `log10(n)` | Base-10 logarithm |
  | `sum(a, b, ...)` | Sums any number of arguments |
  | `avg(a, b, ...)` | Arithmetic mean |

  ### String

  | Function | Description |
  |----------|-------------|
  | `len(s)` | String length |
  | `left(s, n)` | First `n` characters |
  | `right(s, n)` | Last `n` characters |
  | `substring(s, start)` | Substring from `start` to end |
  | `substring(s, start, len)` | Substring of `len` characters |
  | `upper(s)` | Converts to uppercase |
  | `lower(s)` | Converts to lowercase |
  | `trim(s)` | Removes leading/trailing whitespace |
  | `concat(a, b, ...)` | Concatenates values into a string |
  | `textjoin(delim, a, b, ...)` | Joins values with a delimiter |
  | `replace(s, old, new)` | Replaces all occurrences of `old` with `new` |
  | `find(search, text)` | 0-based position of `search` in `text`, or -1 |
  | `contains(s, term)` | Returns `true` if `term` exists within `s` |
  | `normalize(s)` | Downcases and replaces spaces with underscores |

  ### Utility

  | Function | Description |
  |----------|-------------|
  | `if(cond, t, f)` | Returns `t` if `cond` is truthy, otherwise `f` |
  | `ifnull(val, default)` | Returns `default` if `val` is nil |
  | `coalesce(a, b, ...)` | Returns the first non-nil value |
  | `switch(expr, c1, v1, ..., default)` | Multi-way value matching |
  | `and(a, b, ...)` | Returns `true` if all arguments are truthy |
  | `or(a, b, ...)` | Returns `true` if any argument is truthy |
  | `lookup(coll, key)` | Looks up `key` in a map or index in a list |
  | `lookup(coll, key, default)` | Same, with a default for missing keys |

  Custom functions can be added via the `ExCellerate.Registry` system.

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

  Returns `{:ok, result}` on success or `{:error, %ExCellerate.Error{}}` on failure.

  ## Parameters

  - `expression` — a string containing the expression.
  - `scope` — a map of variables available to the expression. Supports string
    keys, atom keys, and structs. Defaults to `%{}`.
  - `registry` — an optional module created with `use ExCellerate.Registry`.

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
  Similar to `eval/3`, but returns the result directly or raises on error.

  ## Examples

      iex> ExCellerate.eval!("1 + 2 * 3")
      7

      iex> ExCellerate.eval!("a > 10 ? 'high' : 'low'", %{"a" => 15})
      "high"

      iex> ExCellerate.eval!("concat('Hello', ' ', name)", %{"name" => "Alice"})
      "Hello Alice"

      iex> ExCellerate.eval!("user.profile.id", %{"user" => %{"profile" => %{"id" => 1}}})
      1

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
  Similar to `compile/2`, but returns the function directly or raises on error.

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
