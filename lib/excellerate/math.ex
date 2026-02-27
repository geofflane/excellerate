defmodule ExCellerate.Math do
  @moduledoc false
  # Internal: Utility module for mathematical operations like factorial.

  # Calculates the factorial of a non-negative integer.
  @spec factorial(non_neg_integer()) :: pos_integer()
  def factorial(0), do: 1
  def factorial(n) when is_integer(n) and n > 0, do: n * factorial(n - 1)

  def factorial(n) when is_number(n) and n < 0 do
    raise ExCellerate.Error,
      message: "factorial is not defined for negative numbers",
      type: :runtime
  end

  def factorial(n) when is_float(n) do
    raise ExCellerate.Error,
      message: "factorial requires an integer argument, got #{n}",
      type: :runtime
  end
end
