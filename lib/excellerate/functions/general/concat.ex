defmodule ExCellerate.Functions.General.Concat do
  @moduledoc """
  Concatenates all arguments into a single string.

  Non-string values are converted to their text representation before
  joining. Accepts any number of arguments.

  ## Examples

      concat('foo', 'bar')    → 'foobar'
      concat('a', 1, true)    → 'a1true'
      concat('Hello', ' ', name) → 'Hello Alice' (when name is 'Alice')
  """
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "concat"
  @impl true
  def arity, do: :any

  @impl true
  def call(args) do
    Enum.map_join(args, "", &to_string/1)
  end
end
