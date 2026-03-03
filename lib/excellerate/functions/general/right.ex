defmodule ExCellerate.Functions.General.Right do
  @moduledoc """
  Returns the last *n* characters from a string.

  When called with one argument, returns the last character. With two
  arguments, returns the last *n* characters.

  ## Examples

      right('Hello World', 5) → 'World'
      right('Hello')          → 'o'
      right('Hi', 10)         → 'Hi'
  """
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
