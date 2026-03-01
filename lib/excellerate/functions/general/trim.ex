defmodule ExCellerate.Functions.General.Trim do
  @moduledoc false
  # Internal: Implements the 'trim' function — removes leading/trailing whitespace.
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "trim"
  @impl true
  def arity, do: 1

  @impl true
  def call([str]) do
    ensure_string!(str, name())
    String.trim(str)
  end
end
