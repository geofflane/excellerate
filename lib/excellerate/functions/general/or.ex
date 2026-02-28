defmodule ExCellerate.Functions.General.Or do
  @moduledoc false
  # Internal: Implements the 'or' function — returns true if any argument is truthy.
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
