defmodule ExCellerate.Functions.General.Table do
  @moduledoc false
  @behaviour ExCellerate.Function

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
    ensure_equal_lengths!(lists)

    lists
    |> Enum.zip()
    |> Enum.map(fn row ->
      keys
      |> Enum.zip(Tuple.to_list(row))
      |> Map.new()
    end)
  end

  defp extract_keys_and_lists(pairs) do
    Enum.reduce(pairs, {[], []}, fn
      [key, list], {keys, lists} when is_binary(key) and is_list(list) ->
        {keys ++ [key], lists ++ [list]}

      [key, _value], _acc when not is_binary(key) ->
        raise ExCellerate.Error,
          message: "'#{name()}' expects string keys, got: #{inspect(key)}",
          type: :runtime

      [_key, value], _acc when not is_list(value) ->
        raise ExCellerate.Error,
          message: "'#{name()}' expects list values, got: #{inspect(value)}",
          type: :runtime
    end)
  end

  defp ensure_equal_lengths!([]), do: :ok

  defp ensure_equal_lengths!(lists) do
    lengths = Enum.map(lists, &length/1)

    unless Enum.all?(lengths, &(&1 == hd(lengths))) do
      raise ExCellerate.Error,
        message: "'#{name()}' requires all lists to have the same length",
        type: :runtime
    end
  end
end
