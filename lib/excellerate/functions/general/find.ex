defmodule ExCellerate.Functions.General.Find do
  @moduledoc false
  # Internal: Implements the 'find' function — returns the 0-based index
  # of the first occurrence of search in text, or -1 if not found.
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
