defmodule ExCellerate.Functions.Math.Floor do
  @moduledoc """
  Rounds a number down to the nearest integer.

  ## Examples

      floor(1.9)  → 1
      floor(3.0)  → 3
      floor(-1.2) → -2
  """
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "floor"
  @impl true
  def arity, do: 1
  @impl true
  def call([n]), do: floor(n)
end
