defmodule ExCellerate.Functions.General.Trim do
  @moduledoc false
  # Internal: Implements the 'trim' function — removes leading/trailing whitespace.
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "trim"
  @impl true
  def arity, do: 1

  @impl true
  def call([str]) when is_binary(str), do: String.trim(str)
end
