defmodule ExCellerate.Functions.Math.Ceil do
  @moduledoc false
  # Internal: Implements the 'ceil' function.
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "ceil"
  @impl true
  def arity, do: 1
  @impl true
  def call([n]), do: ceil(n)
end
