defmodule ExCellerate.Functions.General.Table do
  @moduledoc """
  Builds a list of maps (rows) from column name/list pairs.

  Arguments are provided in pairs: `column_name, values_list, ...`. All
  value lists must be the same length. Each row in the result is a map
  with the column names as keys.

  ## Examples

      table('name', names, 'score', scores)
        → [{'name': 'Alice', 'score': 90}, {'name': 'Bob', 'score': 85}]
        (when names is ['Alice', 'Bob'] and scores is [90, 85])
  """
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "table"

  @impl true
  def arity, do: :any

  @impl true
  def call(args) when is_list(args) do
    ensure_even_args!(args, name())

    pairs = Enum.chunk_every(args, 2)
    {keys, lists} = extract_keys_and_lists(pairs)
    ensure_uniform_length!(lists, name())

    lists
    |> Enum.zip()
    |> Enum.map(fn row ->
      keys
      |> Enum.zip(Tuple.to_list(row))
      |> Map.new()
    end)
  end

  defp extract_keys_and_lists(pairs) do
    Enum.reduce(pairs, {[], []}, fn [key, value], {keys, lists} ->
      ensure_string!(key, name())
      ensure_list!(value, name())
      {keys ++ [key], lists ++ [value]}
    end)
  end
end
