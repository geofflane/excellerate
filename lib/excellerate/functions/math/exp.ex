defmodule ExCellerate.Functions.Math.Exp do
  @moduledoc """
  Returns *e* raised to the given power.

  ## Examples

      exp(0) → 1.0
      exp(1) → 2.718281828...
  """
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
