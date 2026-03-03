defmodule ExCellerate.Functions.Math.Max do
  @moduledoc """
  Returns the largest of the given values.

  Accepts any number of arguments.

  ## Examples

      max(5)              → 5
      max(3, 1, 2)        → 3
      max(10, 20, 5, 15)  → 20
  """
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "max"
  @impl true
  def arity, do: :any

  @impl true
  def call([list]) when is_list(list), do: Enum.max(list)
  def call(args), do: Enum.max(args)
end
