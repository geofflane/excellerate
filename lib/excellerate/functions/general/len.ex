defmodule ExCellerate.Functions.General.Len do
  @moduledoc false
  # Internal: Implements the 'len' function — returns the length of a string.
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "len"
  @impl true
  def arity, do: 1

  @impl true
  def call([str]) when is_binary(str), do: String.length(str)
end
