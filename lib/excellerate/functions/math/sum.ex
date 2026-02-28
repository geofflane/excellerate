defmodule ExCellerate.Functions.Math.Sum do
  @moduledoc false
  # Internal: Implements the 'sum' function — sums a variable number of arguments.
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "sum"
  @impl true
  def arity, do: :any

  @impl true
  def call(args), do: Enum.sum(args)
end
