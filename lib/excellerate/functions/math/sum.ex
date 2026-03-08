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

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "sum"
  @impl true
  def arity, do: :any

  @impl true
  def call([list]) when is_list(list) do
    Enum.each(list, &ensure_number!(&1, name()))
    Enum.sum(list)
  end

  def call(args) do
    Enum.each(args, &ensure_number!(&1, name()))
    Enum.sum(args)
  end
end
