defmodule ExCellerate.Functions.General.Left do
  @moduledoc false
  # Internal: Implements the 'left' function — returns the first n characters.
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "left"
  @impl true
  def arity, do: 1..2

  @impl true
  def call([str]) do
    ensure_string!(str, name())
    String.slice(str, 0, 1)
  end

  def call([str, n]) do
    ensure_string!(str, name())
    ensure_integer!(n, name())
    String.slice(str, 0, n)
  end
end
