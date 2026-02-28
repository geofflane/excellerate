defmodule ExCellerate.Functions.General.And do
  @moduledoc false
  # Internal: Implements the 'and' function — returns true if all arguments are truthy.
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
