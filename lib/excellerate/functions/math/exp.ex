defmodule ExCellerate.Functions.Math.Exp do
  @moduledoc false
  # Internal: Implements the 'exp' function — e raised to the power.
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "exp"
  @impl true
  def arity, do: 1

  @impl true
  def call([n]) do
    ensure_number!(n, name())
    :math.exp(n)
  end
end
