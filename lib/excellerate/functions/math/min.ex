defmodule ExCellerate.Functions.Math.Min do
  @moduledoc false
  # Internal: Implements the 'min' function — minimum of two values or a list.
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "min"
  @impl true
  def arity, do: :any

  @impl true
  def call([list]) when is_list(list), do: Enum.min(list)
  def call([a, b]), do: min(a, b)
end
