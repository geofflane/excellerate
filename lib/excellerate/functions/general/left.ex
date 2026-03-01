defmodule ExCellerate.Functions.General.Left do
  @moduledoc false
  # Internal: Implements the 'left' function — returns the first n characters.
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "left"
  @impl true
  def arity, do: 2

  @impl true
  def call([str, n]) when is_binary(str) and is_integer(n) do
    String.slice(str, 0, n)
  end

  def call([str, n]) do
    ensure_string!(str, name())
    ensure_integer!(n, name())
  end
end
