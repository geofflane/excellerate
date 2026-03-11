defmodule ExCellerate.Functions.DateTime.Dateadd do
  @moduledoc """
  Shifts a date or datetime by the specified amount and unit.

  Returns the same type as the input: `Date` in → `Date` out,
  `NaiveDateTime` in → `NaiveDateTime` out, `DateTime` in → `DateTime` out.

  When adding sub-day units (`hours`, `minutes`, `seconds`, `milliseconds`)
  to a `Date`, the result is promoted to a `NaiveDateTime` since a `Date`
  cannot represent time-of-day.

  For `months` and `years`, end-of-month clamping is applied: e.g.,
  Jan 31 + 1 month = Feb 28 (or Feb 29 in a leap year).

  ## Examples

      dateadd(date(2024, 1, 15), 10, 'days')    → ~D[2024-01-25]
      dateadd(date(2024, 1, 31), 1, 'months')   → ~D[2024-02-29]
      dateadd(date(2024, 1, 15), 3, 'hours')    → ~N[2024-01-15 03:00:00]
  """
  @behaviour ExCellerate.Function

  alias Date, as: D
  alias DateTime, as: DT
  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "dateadd"
  @impl true
  def arity, do: 3

  @impl true
  def call([date, amount, unit]) do
    ensure_date_or_datetime!(date, name())
    ensure_integer!(amount, name())
    ensure_date_unit!(unit, name())

    add(date, amount, unit)
  end

  # ── Days ──────────────────────────────────────────────────────────

  defp add(%D{} = d, amount, "days") do
    D.add(d, amount)
  end

  defp add(%NaiveDateTime{} = ndt, amount, "days") do
    NaiveDateTime.add(ndt, amount * 86_400, :second)
  end

  defp add(%DT{} = dt, amount, "days") do
    DT.add(dt, amount * 86_400, :second)
  end

  # ── Months ────────────────────────────────────────────────────────

  defp add(date, amount, "months") do
    shift_calendar(date, months: amount)
  end

  # ── Years ─────────────────────────────────────────────────────────

  defp add(date, amount, "years") do
    shift_calendar(date, months: amount * 12)
  end

  # ── Sub-day units ─────────────────────────────────────────────────

  defp add(%D{} = d, amount, unit)
       when unit in ~w(hours minutes seconds milliseconds) do
    {:ok, ndt} = NaiveDateTime.new(d, ~T[00:00:00])
    add(ndt, amount, unit)
  end

  defp add(%NaiveDateTime{} = ndt, amount, "hours") do
    NaiveDateTime.add(ndt, amount * 3_600, :second)
  end

  defp add(%NaiveDateTime{} = ndt, amount, "minutes") do
    NaiveDateTime.add(ndt, amount * 60, :second)
  end

  defp add(%NaiveDateTime{} = ndt, amount, "seconds") do
    NaiveDateTime.add(ndt, amount, :second)
  end

  defp add(%NaiveDateTime{} = ndt, amount, "milliseconds") do
    NaiveDateTime.add(ndt, amount, :millisecond)
  end

  defp add(%DT{} = dt, amount, "hours") do
    DT.add(dt, amount * 3_600, :second)
  end

  defp add(%DT{} = dt, amount, "minutes") do
    DT.add(dt, amount * 60, :second)
  end

  defp add(%DT{} = dt, amount, "seconds") do
    DT.add(dt, amount, :second)
  end

  defp add(%DT{} = dt, amount, "milliseconds") do
    DT.add(dt, amount, :millisecond)
  end

  # ── Calendar shifting (months/years with clamping) ────────────────

  defp shift_calendar(%D{} = d, months: months) do
    {year, month, day} = shift_ym(d.year, d.month, d.day, months)
    {:ok, result} = D.new(year, month, day)
    result
  end

  defp shift_calendar(%NaiveDateTime{} = ndt, months: months) do
    {year, month, day} = shift_ym(ndt.year, ndt.month, ndt.day, months)
    {:ok, result} = NaiveDateTime.new(year, month, day, ndt.hour, ndt.minute, ndt.second)
    %{result | microsecond: ndt.microsecond}
  end

  defp shift_calendar(%DT{} = dt, months: months) do
    {year, month, day} = shift_ym(dt.year, dt.month, dt.day, months)

    {:ok, naive} = NaiveDateTime.new(year, month, day, dt.hour, dt.minute, dt.second)
    naive = %{naive | microsecond: dt.microsecond}

    {:ok, result} = DT.from_naive(naive, dt.time_zone)
    result
  end

  # Shifts year/month by N months and clamps the day to the target month.
  defp shift_ym(year, month, day, months) do
    total_months = year * 12 + (month - 1) + months
    new_year = div(total_months, 12)
    new_month = rem(total_months, 12) + 1

    {new_year, new_month} =
      if new_month < 1 do
        {new_year - 1, new_month + 12}
      else
        {new_year, new_month}
      end

    max_day = D.days_in_month(%D{year: new_year, month: new_month, day: 1})
    {new_year, new_month, min(day, max_day)}
  end
end
