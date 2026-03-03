defmodule ExCellerate.Functions.General.Coalesce do
  @moduledoc """
  Returns the first non-null value from the given arguments.

  Returns `null` if all arguments are `null`. Accepts any number of
  arguments.

  ## Examples

      coalesce(null, null, 'found') → 'found'
      coalesce('first', 'second')   → 'first'
      coalesce(a, b, 0)             → 0 (when a and b are null)
  """
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "coalesce"
  @impl true
  def arity, do: :any

  @impl true
  def call(args) do
    Enum.find(args, &(not is_nil(&1)))
  end
end
