defmodule ExCellerate.Functions.General.Table do
  @moduledoc false
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "table"

  @impl true
  def arity, do: :any

  @impl true
  def call(args) when is_list(args) do
    if args == [] or rem(length(args), 2) != 0 do
      raise ExCellerate.Error,
        message: "'#{name()}' expects an even number of arguments: key1, list1, key2, list2, ...",
        type: :runtime
    end

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
