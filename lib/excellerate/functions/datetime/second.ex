defmodule ExCellerate.Functions.DateTime.Second do
  @moduledoc """
  Extracts the second (0-59) from a datetime.

  Accepts `Date`, `NaiveDateTime`, or `DateTime` structs. When given a
  `Date` (which has no time component), returns `0` (midnight).

  ## Examples

      second(datetime(2024, 1, 15, 13, 30, 45))  → 45
      second(date(2024, 1, 15))                   → 0
  """
  @behaviour ExCellerate.Function

  alias Date, as: D
  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "second"
  @impl true
  def arity, do: 1

  @impl true
  def call([%D{}]), do: 0

  def call([value]) do
    ensure_date_or_datetime!(value, name())
    value.second
  end
end
