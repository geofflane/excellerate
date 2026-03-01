defmodule ExCellerate.Functions.General.Filter do
  @moduledoc false
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "filter"

  @impl true
  def arity, do: 2

  @impl true
  def call([list, predicate]) when is_list(list) and is_list(predicate) do
    ensure_paired_length!(list, predicate, name())

    Enum.zip(list, predicate)
    |> Enum.reduce([], fn {item, keep?}, acc ->
      keep = ensure_boolean!(keep?, name())
      if keep, do: [item | acc], else: acc
    end)
    |> Enum.reverse()
  end

  @impl true
  def call([_list, _predicate]) do
    raise ExCellerate.Error,
      message: "'#{name()}' expects a list and a list of booleans",
      type: :runtime
  end
end
