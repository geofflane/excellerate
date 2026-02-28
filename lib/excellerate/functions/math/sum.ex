defmodule ExCellerate.Functions.Math.Sum do
  @moduledoc false
  # Internal: Implements the 'sum' function — sums arguments or a list.
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "sum"
  @impl true
  def arity, do: :any

  @impl true
  def call([list]) when is_list(list), do: Enum.sum(list)
  def call(args), do: Enum.sum(args)
end
