defmodule ExCellerate.Functions.General.Lookup do
  @moduledoc """
  Retrieves a value from a map by key or from a list by index.

  An optional third argument provides a default value to return when the
  key or index is not found. Without a default, returns `null`.

  ## Examples

      lookup(user, 'name')              → 'Alice' (when user.name is 'Alice')
      lookup(items, 0)                  → 'first' (first element of list)
      lookup(user, 'role', 'guest')     → 'guest' (when 'role' key is missing)
      lookup(items, 99, 'out of range') → 'out of range'
  """
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "lookup"
  @impl true
  def arity, do: 2..3

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
