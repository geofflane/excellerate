defmodule ExCellerate.Functions.General.Upper do
  @moduledoc false
  # Internal: Implements the 'upper' function — converts a string to uppercase.
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "upper"
  @impl true
  def arity, do: 1

  @impl true
  def call([str]) when is_binary(str), do: String.upcase(str)
  def call([other]), do: ensure_string!(other, name())
end
