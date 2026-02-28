defmodule ExCellerate.Functions.General.Coalesce do
  @moduledoc false
  # Internal: Implements the 'coalesce' function — returns the first non-nil value.
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
