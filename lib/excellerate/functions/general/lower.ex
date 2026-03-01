defmodule ExCellerate.Functions.General.Lower do
  @moduledoc false
  # Internal: Implements the 'lower' function — converts a string to lowercase.
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "lower"
  @impl true
  def arity, do: 1

  @impl true
  def call([str]) when is_binary(str), do: String.downcase(str)
  def call([other]), do: ensure_string!(other, name())
end
