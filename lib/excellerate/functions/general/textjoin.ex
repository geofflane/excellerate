defmodule ExCellerate.Functions.General.TextJoin do
  @moduledoc """
  Joins values into a single string using a delimiter.

  The first argument is the delimiter; all remaining arguments are the
  values to join. Non-string values are converted to text automatically.

  ## Examples

      textjoin(', ', 'a', 'b', 'c') → 'a, b, c'
      textjoin('-', 1, 2, 3)        → '1-2-3'
      textjoin(' ', first, last)     → 'Jane Doe' (when first is 'Jane', last is 'Doe')
  """
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "textjoin"
  @impl true
  def arity, do: :any

  @impl true
  def call([delimiter | values]) do
    values
    |> List.flatten()
    |> Enum.map_join(to_string(delimiter), &to_string/1)
  end
end
