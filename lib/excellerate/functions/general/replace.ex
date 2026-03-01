defmodule ExCellerate.Functions.General.Replace do
  @moduledoc false
  # Internal: Implements the 'replace' function — replaces all occurrences
  # of a substring. Equivalent to Excel's SUBSTITUTE.
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
