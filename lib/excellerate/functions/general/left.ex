defmodule ExCellerate.Functions.General.Left do
  @moduledoc false
  # Internal: Implements the 'left' function — returns the first n characters.
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "left"
  @impl true
  def arity, do: 2

  @impl true
  def call([str, n]) when is_binary(str) and is_integer(n) do
    String.slice(str, 0, n)
  end
end
