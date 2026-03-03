defmodule ExCellerate.Functions.General.Replace do
  @moduledoc """
  Replaces all occurrences of a substring with a replacement string.

  ## Examples

      replace('hello world', 'world', 'there') → 'hello there'
      replace('aaa', 'a', 'b')                 → 'bbb'
      replace('hello', 'xyz', 'abc')            → 'hello'
  """
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "replace"
  @impl true
  def arity, do: 3

  @impl true
  def call([str, pattern, replacement]) do
    ensure_string!(str, name())
    ensure_string!(pattern, name())
    ensure_string!(replacement, name())
    String.replace(str, pattern, replacement)
  end
end
