defmodule ExCellerate.Functions.General.Or do
  @moduledoc """
  Returns `true` if any argument is truthy, `false` otherwise.

  Accepts any number of arguments.

  ## Examples

      or(false, false, true)  → true
      or(false, false, false) → false
      or(active, override)    → true (when either is true)
  """
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "or"
  @impl true
  def arity, do: :any

  @impl true
  def call(args) do
    Enum.any?(args, & &1)
  end
end
