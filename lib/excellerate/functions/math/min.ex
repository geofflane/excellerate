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

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "min"
  @impl true
  def arity, do: :any

  @impl true
  def call([list]) when is_list(list) do
    Enum.each(list, &ensure_number!(&1, name()))
    Enum.min(list)
  end

  def call(args) do
    Enum.each(args, &ensure_number!(&1, name()))
    Enum.min(args)
  end
end
