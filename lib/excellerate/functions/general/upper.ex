defmodule ExCellerate.Functions.General.Upper do
  @moduledoc """
  Converts a string to uppercase.

  ## Examples

      upper('hello')       → 'HELLO'
      upper('Hello World') → 'HELLO WORLD'
  """
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "upper"
  @impl true
  def arity, do: 1

  @impl true
  def call([str]) do
    ensure_string!(str, name())
    String.upcase(str)
  end
end
