defmodule ExCellerate.Functions.Math.Abs do
  @moduledoc """
  Returns the absolute value of a number.

  ## Examples

      abs(-10)   → 10
      abs(5)     → 5
      abs(-3.14) → 3.14
  """
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "abs"
  @impl true
  def arity, do: 1
  @impl true
  def call([n]), do: abs(n)
end
