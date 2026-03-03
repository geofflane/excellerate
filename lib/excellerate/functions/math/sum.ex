defmodule ExCellerate.Functions.Math.Sum do
  @moduledoc """
  Returns the sum of the given values.

  Accepts any number of numeric arguments.

  ## Examples

      sum(1, 2, 3)    → 6
      sum(10)         → 10
      sum(a, b, c)    → (sum of a, b, and c)
  """
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "sum"
  @impl true
  def arity, do: :any

  @impl true
  def call([list]) when is_list(list), do: Enum.sum(list)
  def call(args), do: Enum.sum(args)
end
