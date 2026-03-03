defmodule ExCellerate.Functions.Math.Avg do
  @moduledoc """
  Returns the arithmetic mean (average) of the given values.

  Accepts any number of numeric arguments.

  ## Examples

      avg(2, 4, 6) → 4.0
      avg(10)      → 10.0
      avg(1, 2)    → 1.5
  """
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "avg"
  @impl true
  def arity, do: :any

  @impl true
  def call([list]) when is_list(list), do: Enum.sum(list) / length(list)
  def call(args), do: Enum.sum(args) / length(args)
end
