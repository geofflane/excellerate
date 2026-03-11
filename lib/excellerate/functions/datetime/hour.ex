defmodule ExCellerate.Functions.DateTime.Hour do
  @moduledoc """
  Extracts the hour (0-23) from a datetime.

  Accepts `Date`, `NaiveDateTime`, or `DateTime` structs. When given a
  `Date` (which has no time component), returns `0` (midnight).

  ## Examples

      hour(datetime(2024, 1, 15, 13, 30, 0))  → 13
      hour(date(2024, 1, 15))                 → 0
  """
  @behaviour ExCellerate.Function

  alias Date, as: D
  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "hour"
  @impl true
  def arity, do: 1

  @impl true
  def call([%D{}]), do: 0

  def call([value]) do
    ensure_date_or_datetime!(value, name())
    value.hour
  end
end
