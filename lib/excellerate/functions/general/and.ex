defmodule ExCellerate.Functions.General.And do
  @moduledoc """
  Returns `true` if all arguments are truthy, `false` otherwise.

  Accepts any number of arguments.

  ## Examples

      and(true, true, true)  → true
      and(true, false, true) → false
      and(score > 50, age >= 18) → true (when both conditions hold)
  """
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "and"
  @impl true
  def arity, do: :any

  @impl true
  def call(args) do
    Enum.all?(args, & &1)
  end
end
