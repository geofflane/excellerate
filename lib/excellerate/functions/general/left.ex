defmodule ExCellerate.Functions.General.Left do
  @moduledoc """
  Returns the first *n* characters from a string.

  When called with one argument, returns the first character. With two
  arguments, returns the first *n* characters.

  ## Examples

      left('Hello World', 5) → 'Hello'
      left('Hello')          → 'H'
      left('Hi', 10)         → 'Hi'
  """
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
