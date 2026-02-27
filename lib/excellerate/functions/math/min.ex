defmodule ExCellerate.Functions.Math.Min do
  @moduledoc false
  # Internal: Implements the 'min' function.
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "min"
  @impl true
  def arity, do: 2
  @impl true
  def call([a, b]), do: min(a, b)
end
