defmodule ExCellerate.Functions.DateTime.Datedif do
  @moduledoc """
  Calculates the signed difference between two dates in the specified unit.

  Returns the integer `date2 − date1` expressed in the given unit. The
  result is positive when `date2 > date1` and negative when `date1 > date2`.
  Use `abs()` to obtain an unsigned value.

  Accepts `Date`, `NaiveDateTime`, or `DateTime` structs for both arguments.
  When mixing types, `Date` values are treated as midnight (00:00:00).

  ## Units

  - `"years"` — complete calendar years between the two dates
  - `"months"` — complete calendar months between the two dates
  - `"days"` — total days (truncated toward zero for sub-day precision)
  - `"hours"` — total hours (truncated toward zero)
  - `"minutes"` — total minutes (truncated toward zero)
  - `"seconds"` — total seconds
  - `"milliseconds"` — total milliseconds

  ## Examples

      datedif(date(2024, 1, 1), date(2024, 3, 1), 'days')     → 60
      datedif(date(2020, 6, 15), date(2024, 6, 15), 'years')  → 4
      datedif(date(2024, 3, 1), date(2024, 1, 1), 'days')     → -60
      datedif(date(2024, 4, 15), date(2024, 1, 15), 'months') → -3
      abs(datedif(date(2024, 3, 1), date(2024, 1, 1), 'days')) → 60
  """
  @behaviour ExCellerate.Function

  alias Date, as: D
  alias DateTime, as: DT
  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "datedif"
  @impl true
  def arity, do: 3

  @impl true
  def call([date1, date2, unit]) do
    ensure_date_or_datetime!(date1, name())
    ensure_date_or_datetime!(date2, name())
    ensure_date_unit!(unit, name())

    diff(date1, date2, unit)
  end

  defp diff(date1, date2, "years") do
    {d1, d2, sign} = normalize_dates(date1, date2)
    sign * complete_years(d1, d2)
  end

  defp diff(date1, date2, "months") do
    {d1, d2, sign} = normalize_dates(date1, date2)
    sign * complete_months(d1, d2)
  end

  defp diff(date1, date2, "days") do
    {ndt1, ndt2} = to_naive_pair(date1, date2)
    NaiveDateTime.diff(ndt2, ndt1, :second) |> div(86_400)
  end

  defp diff(date1, date2, "hours") do
    {ndt1, ndt2} = to_naive_pair(date1, date2)
    NaiveDateTime.diff(ndt2, ndt1, :second) |> div(3_600)
  end

  defp diff(date1, date2, "minutes") do
    {ndt1, ndt2} = to_naive_pair(date1, date2)
    NaiveDateTime.diff(ndt2, ndt1, :second) |> div(60)
  end

  defp diff(date1, date2, "seconds") do
    {ndt1, ndt2} = to_naive_pair(date1, date2)
    NaiveDateTime.diff(ndt2, ndt1, :second)
  end

  defp diff(date1, date2, "milliseconds") do
    {ndt1, ndt2} = to_naive_pair(date1, date2)
    NaiveDateTime.diff(ndt2, ndt1, :millisecond)
  end

  # Normalizes so d1 <= d2 and returns {d1, d2, sign}
  defp normalize_dates(date1, date2) do
    d1 = to_date(date1)
    d2 = to_date(date2)

    if D.compare(d1, d2) == :gt do
      {d2, d1, -1}
    else
      {d1, d2, 1}
    end
  end

  defp complete_years(d1, d2) do
    years = d2.year - d1.year

    if D.compare(clamp_date(d2, d1.year), d1) == :lt do
      years - 1
    else
      years
    end
  end

  defp complete_months(d1, d2) do
    total_months = (d2.year - d1.year) * 12 + (d2.month - d1.month)

    if d2.day < d1.day do
      max(total_months - 1, 0)
    else
      total_months
    end
  end

  # Clamp a date struct's day to the valid range for its month/year.
  # Used when shifting year on a date like Feb 29 → non-leap year.
  defp clamp_date(date, year) do
    max_day = D.days_in_month(%D{year: year, month: date.month, day: 1})

    %D{
      year: year,
      month: date.month,
      day: min(date.day, max_day)
    }
  end

  defp to_date(%D{} = d), do: d
  defp to_date(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_date(ndt)
  defp to_date(%DT{} = dt), do: DT.to_date(dt)

  defp to_naive(%D{} = d) do
    {:ok, ndt} = NaiveDateTime.new(d, ~T[00:00:00])
    ndt
  end

  defp to_naive(%NaiveDateTime{} = ndt), do: ndt
  defp to_naive(%DT{} = dt), do: DT.to_naive(dt)

  defp to_naive_pair(d1, d2), do: {to_naive(d1), to_naive(d2)}
end
