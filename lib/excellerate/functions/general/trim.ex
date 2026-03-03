defmodule ExCellerate.Functions.General.Trim do
  @moduledoc """
  Removes leading and trailing whitespace from a string.

  ## Examples

      trim('  hello  ') → 'hello'
      trim('hello')     → 'hello'
  """
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "trim"
  @impl true
  def arity, do: 1

  @impl true
  def call([str]) do
    ensure_string!(str, name())
    String.trim(str)
  end
end
