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

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "max"
  @impl true
  def arity, do: :any

  @impl true
  def call([list]) when is_list(list) do
    Enum.each(list, &ensure_number!(&1, name()))
    Enum.max(list)
  end

  def call(args) do
    Enum.each(args, &ensure_number!(&1, name()))
    Enum.max(args)
  end
end
