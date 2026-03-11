defmodule ExCellerate.Functions.DateTime.Day do
  @moduledoc """
  Extracts the day of the month (1-31) from a date or datetime.

  Accepts `Date`, `NaiveDateTime`, or `DateTime` structs.

  ## Examples

      day(date(2024, 6, 15))  → 15
  """
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "day"
  @impl true
  def arity, do: 1

  @impl true
  def call([value]) do
    ensure_date_or_datetime!(value, name())
    value.day
  end
end
