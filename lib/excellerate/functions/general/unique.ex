defmodule ExCellerate.Functions.General.Unique do
  @moduledoc """
  Returns the unique values from a list, preserving the order of first
  occurrence.

  Accepts a single list or any number of individual arguments.

  ## Examples

      unique(1, 2, 2, 3, 3)    → [1, 2, 3]
      unique(items)             → items with duplicates removed
      unique('a', 'b', 'a')    → ['a', 'b']
  """
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "unique"

  @impl true
  def arity, do: :any

  @impl true
  def call([list]) when is_list(list) do
    Enum.uniq(list)
  end

  def call(args) do
    Enum.uniq(args)
  end
end
