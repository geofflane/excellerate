defmodule ExCellerate.Functions.Math.Trunc do
  @moduledoc """
  Truncates a number toward zero, removing any fractional part.

  Unlike `floor` or `ceil`, `trunc` always drops the decimal portion
  regardless of sign.

  ## Examples

      trunc(3.7)  → 3
      trunc(-3.7) → -3
      trunc(5)    → 5
  """
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "trunc"
  @impl true
  def arity, do: 1

  @impl true
  def call([n]) do
    ensure_number!(n, name())
    trunc(n)
  end
end
