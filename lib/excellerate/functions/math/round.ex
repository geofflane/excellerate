defmodule ExCellerate.Functions.Math.Round do
  @moduledoc false
  # Internal: Implements the 'round' function.
  # round(n) rounds to nearest integer.
  # round(n, digits) rounds to the given number of decimal places.
  # Negative digits round to the left of the decimal point.
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
