defmodule ExCellerate.Functions.Math.Abs do
  @moduledoc false
  # Internal: Implements the 'abs' function.
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "abs"
  @impl true
  def arity, do: 1
  @impl true
  def call([n]), do: abs(n)
end
