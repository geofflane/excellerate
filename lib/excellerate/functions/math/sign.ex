defmodule ExCellerate.Functions.Math.Sign do
  @moduledoc """
  Returns the sign of a number: `-1` for negative, `0` for zero, or `1`
  for positive.

  ## Examples

      sign(-42) → -1
      sign(0)   → 0
      sign(42)  → 1
  """
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "sign"
  @impl true
  def arity, do: 1

  @impl true
  def call([n]) do
    ensure_number!(n, name())

    cond do
      n > 0 -> 1
      n < 0 -> -1
      true -> 0
    end
  end
end
