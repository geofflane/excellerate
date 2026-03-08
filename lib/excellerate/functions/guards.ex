defmodule ExCellerate.Functions.Guards do
  @moduledoc """
  Argument validation helpers for `ExCellerate.Function` implementations.

  These functions validate that arguments meet expected type or structural
  constraints at runtime, raising `ExCellerate.Error` with a descriptive
  message on failure. They are designed to reduce boilerplate in custom
  function modules and produce consistent error messages.

  Every function accepts a `func_name` parameter (the name of the calling
  function) so error messages clearly identify which function received
  bad input.

  ## Usage in a Custom Function

      defmodule MyApp.Functions.Double do
        @behaviour ExCellerate.Function
        import ExCellerate.Functions.Guards

        def name, do: "double"
        def arity, do: 1

        def call([n]) do
          ensure_number!(n, name())
          n * 2
        end
      end

  ## Usage in Built-in Functions

  Built-in functions use these helpers in both guard-matched clauses and
  catch-all error clauses:

      def call([str]) when is_binary(str), do: String.upcase(str)

      def call([other]) do
        ensure_string!(other, name())
      end
  """

  @doc """
  Validates that `value` is a string (binary). Returns `value` on success.

  Raises `ExCellerate.Error` with type `:runtime` if `value` is not a string.

  ## Examples

      iex> ExCellerate.Functions.Guards.ensure_string!("hello", "upper")
      "hello"

      iex> ExCellerate.Functions.Guards.ensure_string!(42, "upper")
      ** (ExCellerate.Error) Runtime error: 'upper' expects a string, got: 42
  """
  @spec ensure_string!(any(), String.t()) :: String.t()
  def ensure_string!(value, _func_name) when is_binary(value), do: value

  def ensure_string!(value, func_name) do
    raise ExCellerate.Error,
      message: "'#{func_name}' expects a string, got: #{inspect(value)}",
      type: :runtime
  end

  @doc """
  Validates that `value` is a number. Returns `value` on success.

  Raises `ExCellerate.Error` with type `:runtime` if `value` is not a number.

  ## Examples

      iex> ExCellerate.Functions.Guards.ensure_number!(42, "sqrt")
      42

      iex> ExCellerate.Functions.Guards.ensure_number!(3.14, "sqrt")
      3.14

      iex> ExCellerate.Functions.Guards.ensure_number!("five", "sqrt")
      ** (ExCellerate.Error) Runtime error: 'sqrt' expects a number, got: "five"
  """
  @spec ensure_number!(any(), String.t()) :: number()
  def ensure_number!(value, _func_name) when is_number(value), do: value

  def ensure_number!(value, func_name) do
    raise ExCellerate.Error,
      message: "'#{func_name}' expects a number, got: #{inspect(value)}",
      type: :runtime
  end

  @doc """
  Validates that `value` is a non-negative number (>= 0). Returns `value`
  on success.

  Raises `ExCellerate.Error` with type `:runtime` if `value` is not a number
  or is negative. The error message always says "expects a non-negative number"
  regardless of whether the value was the wrong type or simply negative.

  ## Examples

      iex> ExCellerate.Functions.Guards.ensure_non_negative_number!(0, "sqrt")
      0

      iex> ExCellerate.Functions.Guards.ensure_non_negative_number!(4.5, "sqrt")
      4.5

      iex> ExCellerate.Functions.Guards.ensure_non_negative_number!(-1, "sqrt")
      ** (ExCellerate.Error) Runtime error: 'sqrt' expects a non-negative number, got: -1

      iex> ExCellerate.Functions.Guards.ensure_non_negative_number!("five", "sqrt")
      ** (ExCellerate.Error) Runtime error: 'sqrt' expects a non-negative number, got: "five"
  """
  @spec ensure_non_negative_number!(any(), String.t()) :: number()
  def ensure_non_negative_number!(value, _func_name) when is_number(value) and value >= 0,
    do: value

  def ensure_non_negative_number!(value, func_name) do
    raise ExCellerate.Error,
      message: "'#{func_name}' expects a non-negative number, got: #{inspect(value)}",
      type: :runtime
  end

  @doc """
  Validates that `value` is an integer. Returns `value` on success.

  Raises `ExCellerate.Error` with type `:runtime` if `value` is not an integer.

  ## Examples

      iex> ExCellerate.Functions.Guards.ensure_integer!(5, "left")
      5

      iex> ExCellerate.Functions.Guards.ensure_integer!(3.5, "left")
      ** (ExCellerate.Error) Runtime error: 'left' expects an integer, got: 3.5
  """
  @spec ensure_integer!(any(), String.t()) :: integer()
  def ensure_integer!(value, _func_name) when is_integer(value), do: value

  def ensure_integer!(value, func_name) do
    raise ExCellerate.Error,
      message: "'#{func_name}' expects an integer, got: #{inspect(value)}",
      type: :runtime
  end

  @doc """
  Validates that `value` is a boolean. Returns `value` on success.

  Raises `ExCellerate.Error` with type `:runtime` if `value` is not a boolean.

  ## Examples

      iex> ExCellerate.Functions.Guards.ensure_boolean!(true, "filter")
      true

      iex> ExCellerate.Functions.Guards.ensure_boolean!(false, "filter")
      false

      iex> ExCellerate.Functions.Guards.ensure_boolean!(1, "filter")
      ** (ExCellerate.Error) Runtime error: 'filter' expects a boolean, got: 1
  """
  @spec ensure_boolean!(any(), String.t()) :: boolean()
  def ensure_boolean!(value, _func_name) when is_boolean(value), do: value

  def ensure_boolean!(value, func_name) do
    raise ExCellerate.Error,
      message: "'#{func_name}' expects a boolean, got: #{inspect(value)}",
      type: :runtime
  end

  @doc """
  Validates that `value` is a list. Returns `value` on success.

  Raises `ExCellerate.Error` with type `:runtime` if `value` is not a list.

  ## Examples

      iex> ExCellerate.Functions.Guards.ensure_list!([1, 2, 3], "sum")
      [1, 2, 3]

      iex> ExCellerate.Functions.Guards.ensure_list!(42, "sum")
      ** (ExCellerate.Error) Runtime error: 'sum' expects a list, got: 42
  """
  @spec ensure_list!(any(), String.t()) :: list()
  def ensure_list!(value, _func_name) when is_list(value), do: value

  def ensure_list!(value, func_name) do
    raise ExCellerate.Error,
      message: "'#{func_name}' expects a list, got: #{inspect(value)}",
      type: :runtime
  end

  @doc """
  Validates that two lists have the same length. Returns `:ok` on success.

  Use this when a function takes two parallel lists that must correspond
  element-by-element (e.g., a data list and a predicate list in `filter`).

  Raises `ExCellerate.Error` with type `:runtime` if the lists differ in length.

  ## Examples

      iex> ExCellerate.Functions.Guards.ensure_paired_length!([1, 2], [true, false], "filter")
      :ok

      iex> ExCellerate.Functions.Guards.ensure_paired_length!([1, 2, 3], [true], "filter")
      ** (ExCellerate.Error) Runtime error: 'filter' expects both lists to have the same length
  """
  @spec ensure_paired_length!(list(), list(), String.t()) :: :ok
  def ensure_paired_length!(list_a, list_b, func_name) do
    if length(list_a) != length(list_b) do
      raise ExCellerate.Error,
        message: "'#{func_name}' expects both lists to have the same length",
        type: :runtime
    end

    :ok
  end

  @doc """
  Validates that an argument list has an even number of elements. Returns
  `:ok` on success.

  Use this when a function expects paired arguments (e.g., condition/value
  pairs in `ifs`, or key/list pairs in `table`).

  Raises `ExCellerate.Error` with type `:runtime` if the count is zero or odd.

  ## Examples

      iex> ExCellerate.Functions.Guards.ensure_even_args!([1, 2, 3, 4], "ifs")
      :ok

      iex> ExCellerate.Functions.Guards.ensure_even_args!([1, 2, 3], "ifs")
      ** (ExCellerate.Error) Runtime error: 'ifs' requires an even number of arguments (condition/value pairs)

      iex> ExCellerate.Functions.Guards.ensure_even_args!([], "table")
      ** (ExCellerate.Error) Runtime error: 'table' requires an even number of arguments (condition/value pairs)
  """
  @spec ensure_even_args!(list(), String.t()) :: :ok
  def ensure_even_args!(args, func_name) when is_list(args) do
    if args == [] or rem(length(args), 2) != 0 do
      raise ExCellerate.Error,
        message: "'#{func_name}' requires an even number of arguments (condition/value pairs)",
        type: :runtime
    end

    :ok
  end

  @doc """
  Validates that all lists in a collection have the same length. Returns `:ok`
  on success.

  Use this when a function takes multiple column lists that must all have
  the same number of elements (e.g., the value lists in `table`).

  Accepts an empty list (vacuously true). Raises `ExCellerate.Error` with
  type `:runtime` if any list differs in length.

  ## Examples

      iex> ExCellerate.Functions.Guards.ensure_uniform_length!([[1, 2], [3, 4], [5, 6]], "table")
      :ok

      iex> ExCellerate.Functions.Guards.ensure_uniform_length!([], "table")
      :ok

      iex> ExCellerate.Functions.Guards.ensure_uniform_length!([[1, 2], [3]], "table")
      ** (ExCellerate.Error) Runtime error: 'table' expects all lists to have the same length
  """
  @spec ensure_uniform_length!(list(list()), String.t()) :: :ok
  def ensure_uniform_length!([], _func_name), do: :ok

  def ensure_uniform_length!(lists, func_name) do
    [first | rest] = Enum.map(lists, &length/1)

    unless Enum.all?(rest, &(&1 == first)) do
      raise ExCellerate.Error,
        message: "'#{func_name}' expects all lists to have the same length",
        type: :runtime
    end

    :ok
  end
end
