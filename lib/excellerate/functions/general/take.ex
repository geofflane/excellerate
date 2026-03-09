defmodule ExCellerate.Functions.General.Take do
  @moduledoc """
  Extracts rows, columns, or both from a list or 2D array.

  Mimics the spreadsheet `TAKE` function. Positive counts take from the
  beginning; negative counts take from the end. Pass `null` to skip a
  dimension.

  ## Examples

      take(data, 3)          → first 3 rows
      take(data, -3)         → last 3 rows
      take(data, null, 2)    → first 2 columns (all rows)
      take(data, 3, 2)       → first 3 rows, first 2 columns
      take(data, -2, -2)     → last 2 rows, last 2 columns
  """
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "take"

  @impl true
  def arity, do: 2..3

  @impl true
  def call([list, rows]) do
    ensure_list!(list, name())
    take_rows(list, rows)
  end

  def call([list, rows, cols]) do
    ensure_list!(list, name())
    list |> take_rows(rows) |> take_cols(cols)
  end

  defp take_rows(list, nil), do: list
  defp take_rows(_list, 0), do: []

  defp take_rows(list, n) do
    ensure_integer!(n, name())
    len = length(list)
    count = min(abs(n), len)

    if n > 0 do
      Enum.take(list, count)
    else
      Enum.drop(list, len - count)
    end
  end

  defp take_cols(list, nil), do: list

  defp take_cols(list, n) do
    ensure_integer!(n, name())

    Enum.map(list, fn row ->
      ensure_list!(row, name())
      width = length(row)
      count = min(abs(n), width)

      if n > 0 do
        Enum.take(row, count)
      else
        Enum.drop(row, width - count)
      end
    end)
  end
end
