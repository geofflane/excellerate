defmodule ExCellerate.Functions.Math.Round do
  @moduledoc false
  # Internal: Implements the 'round' function.
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "round"
  @impl true
  def arity, do: 1
  @impl true
  def call([n]), do: round(n)
end
