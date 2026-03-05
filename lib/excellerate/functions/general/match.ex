defmodule ExCellerate.Functions.General.Match do
  @moduledoc """
  Searches for a value in a list and returns its 0-based position.

  Inspired by Excel's `MATCH` function. The optional `match_type` argument
  controls the matching behaviour:

  - `0` (default) — exact match; the list can be in any order.
  - `1` — finds the position of the largest value that is less than or equal
    to `lookup_value`. The list **must** be in ascending order.
  - `-1` — finds the position of the smallest value that is greater than or
    equal to `lookup_value`. The list **must** be in descending order.

  Returns `null` when no match is found (instead of an error, consistent
  with ExCellerate's nil-propagation philosophy).

  ## Examples

      match('Oranges', fruits)              → 1  (exact match, 0-based)
      match(25, sorted_values, 1)           → position of largest value <= 25
      match(25, desc_values, -1)            → position of smallest value >= 25
      match('missing', items)               → null
  """
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "match"

  @impl true
  def arity, do: 2..3

  @impl true
  def call([lookup_value, list]) do
    ensure_list!(list, name())
    exact_match(lookup_value, list)
  end

  def call([lookup_value, list, match_type]) do
    ensure_list!(list, name())

    case match_type do
      0 ->
        exact_match(lookup_value, list)

      1 ->
        ascending_match(lookup_value, list)

      -1 ->
        descending_match(lookup_value, list)

      _ ->
        raise ExCellerate.Error,
          message: "'#{name()}' match_type must be -1, 0, or 1, got: #{inspect(match_type)}",
          type: :runtime
    end
  end

  defp exact_match(lookup_value, list) do
    case Enum.find_index(list, &(&1 == lookup_value)) do
      nil -> nil
      idx -> idx
    end
  end

  # match_type 1: list is ascending, find largest value <= lookup_value
  defp ascending_match(lookup_value, list) do
    list
    |> Enum.with_index()
    |> Enum.reduce(nil, fn {val, idx}, acc ->
      if is_number(val) and is_number(lookup_value) and val <= lookup_value do
        idx
      else
        acc
      end
    end)
  end

  # match_type -1: list is descending, find smallest value >= lookup_value
  defp descending_match(lookup_value, list) do
    list
    |> Enum.with_index()
    |> Enum.reduce(nil, fn {val, idx}, acc ->
      if is_number(val) and is_number(lookup_value) and val >= lookup_value do
        idx
      else
        acc
      end
    end)
  end
end
