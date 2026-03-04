defmodule ExCellerate.Functions.General.Slice do
  @moduledoc """
  Extracts a contiguous section of a list given a start index and optional
  length.

  The start index is zero-based. Negative indices count from the end of
  the list. When length is omitted, returns everything from the start
  index to the end.

  ## Examples

      slice(items, 1)       → elements from index 1 to end
      slice(items, 1, 3)    → 3 elements starting at index 1
      slice(items, -2)      → last 2 elements
      slice(items, -3, 2)   → 2 elements starting 3 from end
  """
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "slice"

  @impl true
  def arity, do: 2..3

  @impl true
  def call([list, start]) do
    ensure_list!(list, name())
    ensure_integer!(start, name())
    do_slice(list, start, nil)
  end

  def call([list, start, len]) do
    ensure_list!(list, name())
    ensure_integer!(start, name())
    ensure_integer!(len, name())
    ensure_non_negative_length!(len)
    do_slice(list, start, len)
  end

  defp do_slice(list, start, len) do
    size = length(list)
    resolved = resolve_start(start, size)

    cond do
      resolved >= size -> []
      len == nil -> Enum.drop(list, resolved)
      true -> Enum.slice(list, resolved, len)
    end
  end

  defp resolve_start(start, size) when start < 0 do
    max(size + start, 0)
  end

  defp resolve_start(start, _size), do: start

  defp ensure_non_negative_length!(len) when len >= 0, do: :ok

  defp ensure_non_negative_length!(_len) do
    raise ExCellerate.Error,
      message: "'#{name()}' expects a non-negative length",
      type: :runtime
  end
end
