defmodule ExCellerate.Functions.General.TextJoin do
  @moduledoc false
  # Internal: Implements the 'textjoin' function — joins values with a delimiter.
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
