defmodule ExCellerate.Functions.Math.Max do
  @moduledoc false
  # Internal: Implements the 'max' function — maximum of two values or a list.
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "max"
  @impl true
  def arity, do: :any

  @impl true
  def call([list]) when is_list(list), do: Enum.max(list)
  def call([a, b]), do: max(a, b)
end
