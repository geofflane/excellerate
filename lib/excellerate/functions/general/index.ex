defmodule ExCellerate.Functions.General.Index do
  @moduledoc """
  Returns a value from a list or 2D array by position.

  Inspired by Excel's `INDEX` function. Uses 0-based indexing, consistent
  with the rest of ExCellerate.

  - `index(list, row)` — returns the element at position `row` in a 1D list.
  - `index(array, row, col)` — returns the element at `row` and `col` in a
    2D array (list of lists).

  Returns `null` for out-of-bounds positions (consistent with ExCellerate's
  nil-propagation philosophy).

  ## Examples

      index(items, 2)            → third element of items
      index(grid, 1, 2)          → row 1, column 2 of a 2D grid
      index(items, 99)           → null (out of bounds)
  """
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "index"

  @impl true
  def arity, do: 2..3

  @impl true
  def call([_list, nil]), do: nil

  def call([list, row]) do
    ensure_list!(list, name())
    ensure_integer!(row, name())

    if row < 0, do: nil, else: Enum.at(list, row)
  end

  def call([_list, nil, _col]), do: nil
  def call([_list, _row, nil]), do: nil

  def call([list, row, col]) do
    ensure_list!(list, name())
    ensure_integer!(row, name())
    ensure_integer!(col, name())

    if row < 0 or col < 0 do
      nil
    else
      case Enum.at(list, row) do
        nil -> nil
        inner when is_list(inner) -> Enum.at(inner, col)
        _ -> nil
      end
    end
  end
end
