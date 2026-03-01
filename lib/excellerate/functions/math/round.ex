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
  def call([n]) when is_number(n), do: round(n)

  def call([n, digits]) when is_number(n) and is_integer(digits) do
    multiplier = :math.pow(10, digits)
    Float.round(n * multiplier) / multiplier
  end

  def call([n]) do
    ensure_number!(n, name())
  end

  def call([n, digits]) do
    ensure_number!(n, name())
    ensure_integer!(digits, name())
  end
end
