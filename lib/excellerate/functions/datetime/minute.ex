defmodule ExCellerate.Functions.DateTime.Minute do
  @moduledoc """
  Extracts the minute (0-59) from a datetime.

  Accepts `Date`, `NaiveDateTime`, or `DateTime` structs. When given a
  `Date` (which has no time component), returns `0` (midnight).

  ## Examples

      minute(datetime(2024, 1, 15, 13, 30, 0))  → 30
      minute(date(2024, 1, 15))                  → 0
  """
  @behaviour ExCellerate.Function

  alias Date, as: D
  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "minute"
  @impl true
  def arity, do: 1

  @impl true
  def call([%D{}]), do: 0

  def call([value]) do
    ensure_date_or_datetime!(value, name())
    value.minute
  end
end
