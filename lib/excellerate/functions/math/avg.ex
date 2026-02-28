defmodule ExCellerate.Functions.Math.Avg do
  @moduledoc false
  # Internal: Implements the 'avg' function — arithmetic mean of arguments or a list.
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "avg"
  @impl true
  def arity, do: :any

  @impl true
  def call([list]) when is_list(list), do: Enum.sum(list) / length(list)
  def call(args), do: Enum.sum(args) / length(args)
end
