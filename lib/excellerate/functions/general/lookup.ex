defmodule ExCellerate.Functions.General.Lookup do
  @moduledoc false
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "lookup"
  @impl true
  def arity, do: :any

  @impl true
  def call([map, key]) when is_map(map) do
    Map.get(map, key)
  end

  def call([list, index]) when is_list(list) and is_integer(index) do
    Enum.at(list, index)
  end

  def call([map, key, default]) when is_map(map) do
    Map.get(map, key, default)
  end

  def call([list, index, default]) when is_list(list) and is_integer(index) do
    Enum.at(list, index, default)
  end

  def call([_, _, default]), do: default
  def call(_), do: nil
end
