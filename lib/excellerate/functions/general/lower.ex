defmodule ExCellerate.Functions.General.Lower do
  @moduledoc """
  Converts a string to lowercase.

  ## Examples

      lower('HELLO')       → 'hello'
      lower('Hello World') → 'hello world'
  """
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "lower"
  @impl true
  def arity, do: 1

  @impl true
  def call([str]) do
    ensure_string!(str, name())
    String.downcase(str)
  end
end
