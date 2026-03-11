defmodule ExCellerate.Functions.DateTime.Month do
  @moduledoc """
  Extracts the month (1-12) from a date or datetime.

  Accepts `Date`, `NaiveDateTime`, or `DateTime` structs.

  ## Examples

      month(date(2024, 6, 15))  → 6
  """
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "month"
  @impl true
  def arity, do: 1

  @impl true
  def call([value]) do
    ensure_date_or_datetime!(value, name())
    value.month
  end
end
