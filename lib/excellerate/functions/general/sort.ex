defmodule ExCellerate.Functions.General.Sort do
  @moduledoc """
  Sorts values in ascending order.

  Accepts a single list or any number of individual arguments.

  ## Examples

      sort(3, 1, 2)                → [1, 2, 3]
      sort(items)                  → items sorted ascending
      sort('banana', 'apple')     → ['apple', 'banana']
  """
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "sort"

  @impl true
  def arity, do: :any

  @impl true
  def call([list]) when is_list(list) do
    Enum.sort(list)
  end

  def call(args) when is_list(args) do
    Enum.sort(args)
  end
end
