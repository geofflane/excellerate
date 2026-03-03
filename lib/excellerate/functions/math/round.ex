defmodule ExCellerate.Functions.Math.Round do
  @moduledoc """
  Rounds a number to the nearest integer, or to a specified number of
  decimal places.

  When called with one argument, rounds to the nearest integer. With two
  arguments, rounds to the given number of decimal places. Negative digits
  round to the left of the decimal point.

  ## Examples

      round(1.5)        → 2
      round(3.14159, 2) → 3.14
      round(1234, -2)   → 1200.0
  """
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "round"
  @impl true
  def arity, do: 1..2

  @impl true
  def call([n]) do
    ensure_number!(n, name())
    round(n)
  end

  def call([n, digits]) do
    ensure_number!(n, name())
    ensure_integer!(digits, name())
    multiplier = :math.pow(10, digits)
    Float.round(n * multiplier) / multiplier
  end
end
