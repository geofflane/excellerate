defmodule ExCellerate.Functions.General.Substring do
  @moduledoc """
  Extracts a portion of a string starting at a 0-based position.

  With two arguments, returns from the start position to the end of the
  string. With three arguments, returns at most *length* characters.

  Returns `null` if the value is not a string.

  ## Examples

      substring('Hello World', 6)    → 'World'
      substring('Hello World', 0, 5) → 'Hello'
  """
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "substring"
  @impl true
  def arity, do: 2..3

  @impl true
  def call([str, start]) when is_binary(str) and is_integer(start) do
    String.slice(str, start..-1//1)
  end

  def call([str, start, length])
      when is_binary(str) and is_integer(start) and is_integer(length) do
    String.slice(str, start, length)
  end

  def call(_), do: nil
end
