defmodule ExCellerate.Functions.Math.Min do
  @moduledoc """
  Returns the smallest of the given values.

  Accepts any number of arguments.

  ## Examples

      min(5)              → 5
      min(3, 1, 2)        → 1
      min(10, 20, 5, 15)  → 5
  """
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "min"
  @impl true
  def arity, do: :any

  @impl true
  def call([list]) when is_list(list), do: Enum.min(list)
  def call(args), do: Enum.min(args)
end
