defmodule ExCellerate.Functions.General.Filter do
  @moduledoc false
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "filter"

  @impl true
  def arity, do: 2

  @impl true
  def call([list, predicate]) when is_list(list) and is_list(predicate) do
    ensure_same_length!(list, predicate)

    Enum.zip(list, predicate)
    |> Enum.reduce([], fn {item, keep?}, acc ->
      keep = ensure_boolean!(keep?)
      if keep, do: [item | acc], else: acc
    end)
    |> Enum.reverse()
  end

  @impl true
  def call([_list, _predicate]) do
    raise ExCellerate.Error,
      message: "#{name()} expects a list and a list of booleans",
      type: :runtime
  end

  defp ensure_same_length!(list, predicate) do
    if length(list) != length(predicate) do
      raise ExCellerate.Error,
        message: "#{name()} requires predicate list length to match input list length",
        type: :runtime
    end
  end

  defp ensure_boolean!(value) when is_boolean(value), do: value

  defp ensure_boolean!(_value) do
    raise ExCellerate.Error,
      message: "#{name()} expects predicate values to be booleans",
      type: :runtime
  end
end
