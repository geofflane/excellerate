defmodule ExCellerate.Functions.General.Right do
  @moduledoc false
  # Internal: Implements the 'right' function — returns the last n characters.
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "right"
  @impl true
  def arity, do: 2

  @impl true
  def call([str, n]) when is_binary(str) and is_integer(n) do
    len = String.length(str)

    if n >= len do
      str
    else
      String.slice(str, len - n, n)
    end
  end
end
