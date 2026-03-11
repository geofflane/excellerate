defmodule ExCellerate.Functions.DateTime.Weekday do
  @moduledoc """
  Returns the day of the week as an integer (ISO 8601: Monday = 1,
  Sunday = 7).

  Accepts `Date`, `NaiveDateTime`, or `DateTime` structs.

  ## Examples

      weekday(date(2024, 1, 15))  → 1  (Monday)
      weekday(date(2024, 1, 21))  → 7  (Sunday)
  """
  @behaviour ExCellerate.Function

  alias Date, as: D
  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "weekday"
  @impl true
  def arity, do: 1

  @impl true
  def call([value]) do
    ensure_date_or_datetime!(value, name())
    D.day_of_week(value)
  end
end
