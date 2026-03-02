defmodule ExCellerate.Functions.General.IsNull do
  @moduledoc false
  # Internal: Implements the 'isnull' function — returns true if value is nil.
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "isnull"
  @impl true
  def arity, do: 1

  @impl true
  def call([nil]), do: true
  def call([_]), do: false
end
