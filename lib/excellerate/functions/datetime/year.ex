defmodule ExCellerate.Functions.DateTime.Year do
  @moduledoc """
  Extracts the year from a date or datetime.

  Accepts `Date`, `NaiveDateTime`, or `DateTime` structs.

  ## Examples

      year(date(2024, 6, 15))  → 2024
  """
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "year"
  @impl true
  def arity, do: 1

  @impl true
  def call([value]) do
    ensure_date_or_datetime!(value, name())
    value.year
  end
end
