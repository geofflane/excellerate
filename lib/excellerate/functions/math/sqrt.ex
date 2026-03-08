defmodule ExCellerate.Functions.Math.Sqrt do
  @moduledoc """
  Returns the square root of a non-negative number.

  Returns an error if the argument is negative.

  ## Examples

      sqrt(9) → 3.0
      sqrt(2) → 1.4142135...
      sqrt(0) → 0.0
  """
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "sqrt"
  @impl true
  def arity, do: 1

  @impl true
  def call([n]) do
    ensure_non_negative_number!(n, name())
    :math.sqrt(n)
  end
end
