defmodule ExCellerate.Functions.Math.Ceil do
  @moduledoc """
  Rounds a number up to the nearest integer.

  ## Examples

      ceil(1.2)  → 2
      ceil(3.0)  → 3
      ceil(-1.7) → -1
  """
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "ceil"
  @impl true
  def arity, do: 1
  @impl true
  def call([n]), do: ceil(n)
end
