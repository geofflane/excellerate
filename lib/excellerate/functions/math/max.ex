defmodule ExCellerate.Functions.Math.Max do
  @moduledoc false
  # Internal: Implements the 'max' function.
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "max"
  @impl true
  def arity, do: 2
  @impl true
  def call([a, b]), do: max(a, b)
end
