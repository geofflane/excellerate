defmodule ExCellerate.Functions.General.Find do
  @moduledoc """
  Returns the 0-based position of the first occurrence of a search string
  within text, or `-1` if not found.

  An optional third argument specifies a starting position for the search.

  ## Examples

      find('world', 'hello world')    → 6
      find('xyz', 'hello')            → -1
      find('o', 'hello world', 5)     → 7
  """
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "find"
  @impl true
  def arity, do: 2..3

  @impl true
  def call([search, text]) do
    ensure_string!(search, name())
    ensure_string!(text, name())

    case :binary.match(text, search) do
      {pos, _len} -> pos
      :nomatch -> -1
    end
  end

  def call([search, text, start_pos]) do
    ensure_string!(search, name())
    ensure_string!(text, name())
    ensure_integer!(start_pos, name())

    sliced = String.slice(text, start_pos..-1//1)

    case :binary.match(sliced, search) do
      {pos, _len} -> pos + start_pos
      :nomatch -> -1
    end
  end
end
