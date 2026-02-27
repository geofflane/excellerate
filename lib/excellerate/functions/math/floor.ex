defmodule ExCellerate.Functions.Math.Floor do
  @moduledoc false
  # Internal: Implements the 'floor' function.
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "floor"
  @impl true
  def arity, do: 1
  @impl true
  def call([n]), do: floor(n)
end
