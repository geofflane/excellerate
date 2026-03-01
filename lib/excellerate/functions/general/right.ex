defmodule ExCellerate.Functions.General.Right do
  @moduledoc false
  # Internal: Implements the 'right' function — returns the last n characters.
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "right"
  @impl true
  def arity, do: 1..2

  @impl true
  def call([str]) do
    ensure_string!(str, name())
    len = String.length(str)
    if len == 0, do: "", else: String.slice(str, len - 1, 1)
  end

  def call([str, n]) do
    ensure_string!(str, name())
    ensure_integer!(n, name())
    len = String.length(str)

    if n >= len do
      str
    else
      String.slice(str, len - n, n)
    end
  end
end
