defmodule ExCellerate.Math do
  @moduledoc false
  # Internal: Utility module for mathematical operations like factorial.

  # Calculates the factorial of a non-negative integer.
  @spec factorial(non_neg_integer()) :: pos_integer()
  def factorial(0), do: 1
  def factorial(n) when n > 0, do: n * factorial(n - 1)
end
