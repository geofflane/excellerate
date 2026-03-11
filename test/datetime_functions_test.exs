defmodule ExCellerate.DateTimeFunctionsTest do
  use ExUnit.Case, async: true

  # ── Construction ──────────────────────────────────────────────────

  describe "date" do
    test "creates a Date from year, month, day" do
      assert ExCellerate.eval!("date(2024, 1, 15)") == ~D[2024-01-15]
    end

    test "creates a Date from scope variables" do
      scope = %{"y" => 2026, "m" => 3, "d" => 11}
      assert ExCellerate.eval!("date(y, m, d)", scope) == ~D[2026-03-11]
    end

    test "handles leap year" do
      assert ExCellerate.eval!("date(2024, 2, 29)") == ~D[2024-02-29]
    end

    test "rejects invalid date" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("date(2023, 2, 29)")

      assert msg =~ "date"
      assert msg =~ "invalid"
    end

    test "rejects non-integer arguments" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("date(2024, 1.5, 15)")

      assert msg =~ "date"
      assert msg =~ "integer"
    end

    test "rejects wrong arity" do
      assert {:error, %ExCellerate.Error{type: :compiler}} =
               ExCellerate.eval("date(2024, 1)")

      assert {:error, %ExCellerate.Error{type: :compiler}} =
               ExCellerate.eval("date(2024, 1, 15, 0)")
    end
  end

  describe "datetime" do
    test "creates a NaiveDateTime with full arguments" do
      assert ExCellerate.eval!("datetime(2024, 1, 15, 13, 30, 45)") ==
               ~N[2024-01-15 13:30:45]
    end

    test "hour, minute, second default to 0" do
      assert ExCellerate.eval!("datetime(2024, 1, 15)") == ~N[2024-01-15 00:00:00]
    end

    test "minute and second default to 0 when only hour given" do
      assert ExCellerate.eval!("datetime(2024, 1, 15, 13)") == ~N[2024-01-15 13:00:00]
    end

    test "second defaults to 0 when hour and minute given" do
      assert ExCellerate.eval!("datetime(2024, 1, 15, 13, 30)") == ~N[2024-01-15 13:30:00]
    end

    test "rejects invalid datetime" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("datetime(2024, 1, 15, 25, 0, 0)")

      assert msg =~ "datetime"
      assert msg =~ "invalid"
    end

    test "rejects non-integer arguments" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("datetime(2024, 1, 15, 13.5, 30, 45)")

      assert msg =~ "datetime"
      assert msg =~ "integer"
    end

    test "rejects wrong arity" do
      assert {:error, %ExCellerate.Error{type: :compiler}} =
               ExCellerate.eval("datetime(2024, 1)")

      assert {:error, %ExCellerate.Error{type: :compiler}} =
               ExCellerate.eval("datetime(2024, 1, 15, 13, 30, 45, 0)")
    end
  end

  describe "today" do
    test "returns today's date" do
      result = ExCellerate.eval!("today()")
      assert %Date{} = result
      assert result == Date.utc_today()
    end

    test "rejects arguments" do
      assert {:error, %ExCellerate.Error{type: :compiler}} =
               ExCellerate.eval("today(1)")
    end
  end

  describe "now" do
    test "returns current NaiveDateTime" do
      before = NaiveDateTime.utc_now()
      result = ExCellerate.eval!("now()")
      after_now = NaiveDateTime.utc_now()

      assert %NaiveDateTime{} = result
      assert NaiveDateTime.compare(result, before) in [:gt, :eq]
      assert NaiveDateTime.compare(result, after_now) in [:lt, :eq]
    end

    test "rejects arguments" do
      assert {:error, %ExCellerate.Error{type: :compiler}} =
               ExCellerate.eval("now(1)")
    end
  end

  # ── Extraction ────────────────────────────────────────────────────

  describe "year" do
    test "extracts year from Date" do
      scope = %{"d" => ~D[2024-06-15]}
      assert ExCellerate.eval!("year(d)", scope) == 2024
    end

    test "extracts year from NaiveDateTime" do
      scope = %{"d" => ~N[2024-06-15 13:30:00]}
      assert ExCellerate.eval!("year(d)", scope) == 2024
    end

    test "extracts year from DateTime" do
      {:ok, dt, _} = DateTime.from_iso8601("2024-06-15T13:30:00Z")
      scope = %{"d" => dt}
      assert ExCellerate.eval!("year(d)", scope) == 2024
    end

    test "rejects non-date input" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("year(42)")

      assert msg =~ "year"
      assert msg =~ "Date"
    end
  end

  describe "month" do
    test "extracts month from Date" do
      scope = %{"d" => ~D[2024-06-15]}
      assert ExCellerate.eval!("month(d)", scope) == 6
    end

    test "extracts month from NaiveDateTime" do
      scope = %{"d" => ~N[2024-12-25 00:00:00]}
      assert ExCellerate.eval!("month(d)", scope) == 12
    end

    test "extracts month from DateTime" do
      {:ok, dt, _} = DateTime.from_iso8601("2024-01-01T00:00:00Z")
      scope = %{"d" => dt}
      assert ExCellerate.eval!("month(d)", scope) == 1
    end

    test "rejects non-date input" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("month('June')")

      assert msg =~ "month"
      assert msg =~ "Date"
    end
  end

  describe "day" do
    test "extracts day from Date" do
      scope = %{"d" => ~D[2024-06-15]}
      assert ExCellerate.eval!("day(d)", scope) == 15
    end

    test "extracts day from NaiveDateTime" do
      scope = %{"d" => ~N[2024-12-25 13:00:00]}
      assert ExCellerate.eval!("day(d)", scope) == 25
    end

    test "extracts day from DateTime" do
      {:ok, dt, _} = DateTime.from_iso8601("2024-03-01T00:00:00Z")
      scope = %{"d" => dt}
      assert ExCellerate.eval!("day(d)", scope) == 1
    end

    test "rejects non-date input" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("day(15)")

      assert msg =~ "day"
      assert msg =~ "Date"
    end
  end

  describe "hour" do
    test "extracts hour from NaiveDateTime" do
      scope = %{"d" => ~N[2024-06-15 13:30:45]}
      assert ExCellerate.eval!("hour(d)", scope) == 13
    end

    test "extracts hour from DateTime" do
      {:ok, dt, _} = DateTime.from_iso8601("2024-06-15T18:00:00Z")
      scope = %{"d" => dt}
      assert ExCellerate.eval!("hour(d)", scope) == 18
    end

    test "returns 0 for Date (treated as midnight)" do
      scope = %{"d" => ~D[2024-06-15]}
      assert ExCellerate.eval!("hour(d)", scope) == 0
    end

    test "rejects non-date input" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("hour(13)")

      assert msg =~ "hour"
      assert msg =~ "Date"
    end
  end

  describe "minute" do
    test "extracts minute from NaiveDateTime" do
      scope = %{"d" => ~N[2024-06-15 13:30:45]}
      assert ExCellerate.eval!("minute(d)", scope) == 30
    end

    test "extracts minute from DateTime" do
      {:ok, dt, _} = DateTime.from_iso8601("2024-06-15T18:45:00Z")
      scope = %{"d" => dt}
      assert ExCellerate.eval!("minute(d)", scope) == 45
    end

    test "returns 0 for Date (treated as midnight)" do
      scope = %{"d" => ~D[2024-06-15]}
      assert ExCellerate.eval!("minute(d)", scope) == 0
    end

    test "rejects non-date input" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("minute(30)")

      assert msg =~ "minute"
      assert msg =~ "Date"
    end
  end

  describe "second" do
    test "extracts second from NaiveDateTime" do
      scope = %{"d" => ~N[2024-06-15 13:30:45]}
      assert ExCellerate.eval!("second(d)", scope) == 45
    end

    test "extracts second from DateTime" do
      {:ok, dt, _} = DateTime.from_iso8601("2024-06-15T18:45:30Z")
      scope = %{"d" => dt}
      assert ExCellerate.eval!("second(d)", scope) == 30
    end

    test "returns 0 for Date (treated as midnight)" do
      scope = %{"d" => ~D[2024-06-15]}
      assert ExCellerate.eval!("second(d)", scope) == 0
    end

    test "rejects non-date input" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("second(45)")

      assert msg =~ "second"
      assert msg =~ "Date"
    end
  end

  describe "weekday" do
    test "returns day of week for Date (Monday = 1, Sunday = 7)" do
      # 2024-01-15 is a Monday
      scope = %{"d" => ~D[2024-01-15]}
      assert ExCellerate.eval!("weekday(d)", scope) == 1

      # 2024-01-21 is a Sunday
      scope = %{"d" => ~D[2024-01-21]}
      assert ExCellerate.eval!("weekday(d)", scope) == 7

      # 2024-01-17 is a Wednesday
      scope = %{"d" => ~D[2024-01-17]}
      assert ExCellerate.eval!("weekday(d)", scope) == 3
    end

    test "returns day of week for NaiveDateTime" do
      # 2024-01-19 is a Friday
      scope = %{"d" => ~N[2024-01-19 10:00:00]}
      assert ExCellerate.eval!("weekday(d)", scope) == 5
    end

    test "returns day of week for DateTime" do
      {:ok, dt, _} = DateTime.from_iso8601("2024-01-20T12:00:00Z")
      scope = %{"d" => dt}
      # 2024-01-20 is a Saturday
      assert ExCellerate.eval!("weekday(d)", scope) == 6
    end

    test "rejects non-date input" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("weekday(3)")

      assert msg =~ "weekday"
      assert msg =~ "Date"
    end
  end

  # ── DATEDIF ───────────────────────────────────────────────────────

  describe "datedif" do
    test "calculates difference in days between two Dates" do
      scope = %{"d1" => ~D[2024-01-01], "d2" => ~D[2024-03-01]}
      assert ExCellerate.eval!("datedif(d1, d2, 'days')", scope) == 60
    end

    test "calculates difference in days between NaiveDateTimes" do
      scope = %{
        "d1" => ~N[2024-01-01 00:00:00],
        "d2" => ~N[2024-01-03 12:00:00]
      }

      # 2.5 days = 2 full days (integer truncation)
      assert ExCellerate.eval!("datedif(d1, d2, 'days')", scope) == 2
    end

    test "calculates difference in hours" do
      scope = %{
        "d1" => ~N[2024-01-01 00:00:00],
        "d2" => ~N[2024-01-01 05:30:00]
      }

      # 5.5 hours = 5 integer hours
      assert ExCellerate.eval!("datedif(d1, d2, 'hours')", scope) == 5
    end

    test "calculates difference in hours between Dates" do
      scope = %{"d1" => ~D[2024-01-01], "d2" => ~D[2024-01-03]}
      assert ExCellerate.eval!("datedif(d1, d2, 'hours')", scope) == 48
    end

    test "calculates difference in minutes" do
      scope = %{
        "d1" => ~N[2024-01-01 00:00:00],
        "d2" => ~N[2024-01-01 02:30:00]
      }

      assert ExCellerate.eval!("datedif(d1, d2, 'minutes')", scope) == 150
    end

    test "calculates difference in seconds" do
      scope = %{
        "d1" => ~N[2024-01-01 00:00:00],
        "d2" => ~N[2024-01-01 00:05:30]
      }

      assert ExCellerate.eval!("datedif(d1, d2, 'seconds')", scope) == 330
    end

    test "calculates difference in milliseconds" do
      scope = %{
        "d1" => ~N[2024-01-01 00:00:00.000],
        "d2" => ~N[2024-01-01 00:00:01.500]
      }

      assert ExCellerate.eval!("datedif(d1, d2, 'milliseconds')", scope) == 1500
    end

    test "calculates difference in months" do
      scope = %{"d1" => ~D[2024-01-15], "d2" => ~D[2024-04-15]}
      assert ExCellerate.eval!("datedif(d1, d2, 'months')", scope) == 3
    end

    test "calculates difference in months (partial month not counted)" do
      scope = %{"d1" => ~D[2024-01-15], "d2" => ~D[2024-04-14]}
      assert ExCellerate.eval!("datedif(d1, d2, 'months')", scope) == 2
    end

    test "calculates difference in years" do
      scope = %{"d1" => ~D[2020-06-15], "d2" => ~D[2024-06-15]}
      assert ExCellerate.eval!("datedif(d1, d2, 'years')", scope) == 4
    end

    test "calculates difference in years (partial year not counted)" do
      scope = %{"d1" => ~D[2020-06-15], "d2" => ~D[2024-06-14]}
      assert ExCellerate.eval!("datedif(d1, d2, 'years')", scope) == 3
    end

    test "returns negative days when d1 > d2" do
      scope = %{"d1" => ~D[2024-03-01], "d2" => ~D[2024-01-01]}
      assert ExCellerate.eval!("datedif(d1, d2, 'days')", scope) == -60
    end

    test "returns negative months when d1 > d2" do
      scope = %{"d1" => ~D[2024-04-15], "d2" => ~D[2024-01-15]}
      assert ExCellerate.eval!("datedif(d1, d2, 'months')", scope) == -3
    end

    test "returns negative years when d1 > d2" do
      scope = %{"d1" => ~D[2024-06-15], "d2" => ~D[2020-06-15]}
      assert ExCellerate.eval!("datedif(d1, d2, 'years')", scope) == -4
    end

    test "returns negative hours when d1 > d2" do
      scope = %{
        "d1" => ~N[2024-01-01 05:30:00],
        "d2" => ~N[2024-01-01 00:00:00]
      }

      assert ExCellerate.eval!("datedif(d1, d2, 'hours')", scope) == -5
    end

    test "returns negative seconds when d1 > d2" do
      scope = %{
        "d1" => ~N[2024-01-01 00:05:30],
        "d2" => ~N[2024-01-01 00:00:00]
      }

      assert ExCellerate.eval!("datedif(d1, d2, 'seconds')", scope) == -330
    end

    test "returns negative milliseconds when d1 > d2" do
      scope = %{
        "d1" => ~N[2024-01-01 00:00:01.500],
        "d2" => ~N[2024-01-01 00:00:00.000]
      }

      assert ExCellerate.eval!("datedif(d1, d2, 'milliseconds')", scope) == -1500
    end

    test "abs() can be used to get unsigned difference" do
      scope = %{"d1" => ~D[2024-06-15], "d2" => ~D[2020-06-15]}
      assert ExCellerate.eval!("abs(datedif(d1, d2, 'years'))", scope) == 4
    end

    test "returns 0 when dates are equal" do
      scope = %{"d1" => ~D[2024-01-01], "d2" => ~D[2024-01-01]}
      assert ExCellerate.eval!("datedif(d1, d2, 'days')", scope) == 0
    end

    test "works with mixed Date and NaiveDateTime" do
      scope = %{"d1" => ~D[2024-01-01], "d2" => ~N[2024-01-03 12:00:00]}
      assert ExCellerate.eval!("datedif(d1, d2, 'hours')", scope) == 60
    end

    test "works with mixed Date and DateTime" do
      {:ok, dt, _} = DateTime.from_iso8601("2024-01-03T12:00:00Z")
      scope = %{"d1" => ~D[2024-01-01], "d2" => dt}
      assert ExCellerate.eval!("datedif(d1, d2, 'hours')", scope) == 60
    end

    test "accepts singular unit names" do
      scope = %{"d1" => ~D[2024-01-01], "d2" => ~D[2024-03-01]}
      assert ExCellerate.eval!("datedif(d1, d2, 'day')", scope) == 60
      assert ExCellerate.eval!("datedif(d1, d2, 'hour')", scope) == 1440
      assert ExCellerate.eval!("datedif(d1, d2, 'minute')", scope) == 86_400
      assert ExCellerate.eval!("datedif(d1, d2, 'second')", scope) == 5_184_000
    end

    test "accepts singular month and year units" do
      scope = %{"d1" => ~D[2024-01-15], "d2" => ~D[2024-04-15]}
      assert ExCellerate.eval!("datedif(d1, d2, 'month')", scope) == 3

      scope = %{"d1" => ~D[2020-06-15], "d2" => ~D[2024-06-15]}
      assert ExCellerate.eval!("datedif(d1, d2, 'year')", scope) == 4
    end

    test "accepts singular millisecond unit" do
      scope = %{
        "d1" => ~N[2024-01-01 00:00:00.000],
        "d2" => ~N[2024-01-01 00:00:01.500]
      }

      assert ExCellerate.eval!("datedif(d1, d2, 'millisecond')", scope) == 1500
    end

    test "rejects non-date arguments" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("datedif(42, 100, 'days')")

      assert msg =~ "datedif"
      assert msg =~ "Date"
    end

    test "rejects invalid unit" do
      scope = %{"d1" => ~D[2024-01-01], "d2" => ~D[2024-01-02]}

      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("datedif(d1, d2, 'weeks')", scope)

      assert msg =~ "datedif"
      assert msg =~ "valid unit"
    end

    test "rejects wrong arity" do
      assert {:error, %ExCellerate.Error{type: :compiler}} =
               ExCellerate.eval("datedif(d1, d2)")

      assert {:error, %ExCellerate.Error{type: :compiler}} =
               ExCellerate.eval("datedif(d1, d2, 'days', 'extra')")
    end
  end

  # ── DATEADD ───────────────────────────────────────────────────────

  describe "dateadd" do
    test "adds days to a Date" do
      scope = %{"d" => ~D[2024-01-15]}
      assert ExCellerate.eval!("dateadd(d, 10, 'days')", scope) == ~D[2024-01-25]
    end

    test "subtracts days from a Date" do
      scope = %{"d" => ~D[2024-01-15]}
      assert ExCellerate.eval!("dateadd(d, -10, 'days')", scope) == ~D[2024-01-05]
    end

    test "adds days across month boundary" do
      scope = %{"d" => ~D[2024-01-28]}
      assert ExCellerate.eval!("dateadd(d, 5, 'days')", scope) == ~D[2024-02-02]
    end

    test "adds months to a Date" do
      scope = %{"d" => ~D[2024-01-15]}
      assert ExCellerate.eval!("dateadd(d, 3, 'months')", scope) == ~D[2024-04-15]
    end

    test "adds months with end-of-month clamping" do
      # Jan 31 + 1 month = Feb 29 (2024 is leap year)
      scope = %{"d" => ~D[2024-01-31]}
      assert ExCellerate.eval!("dateadd(d, 1, 'months')", scope) == ~D[2024-02-29]
    end

    test "adds months with end-of-month clamping (non-leap year)" do
      # Jan 31 + 1 month in 2023 = Feb 28
      scope = %{"d" => ~D[2023-01-31]}
      assert ExCellerate.eval!("dateadd(d, 1, 'months')", scope) == ~D[2023-02-28]
    end

    test "subtracts months" do
      scope = %{"d" => ~D[2024-03-15]}
      assert ExCellerate.eval!("dateadd(d, -2, 'months')", scope) == ~D[2024-01-15]
    end

    test "adds years to a Date" do
      scope = %{"d" => ~D[2024-06-15]}
      assert ExCellerate.eval!("dateadd(d, 2, 'years')", scope) == ~D[2026-06-15]
    end

    test "subtracts years" do
      scope = %{"d" => ~D[2024-06-15]}
      assert ExCellerate.eval!("dateadd(d, -1, 'years')", scope) == ~D[2023-06-15]
    end

    test "adds years with leap year clamping" do
      # Feb 29, 2024 + 1 year = Feb 28, 2025
      scope = %{"d" => ~D[2024-02-29]}
      assert ExCellerate.eval!("dateadd(d, 1, 'years')", scope) == ~D[2025-02-28]
    end

    test "adds hours to a NaiveDateTime" do
      scope = %{"d" => ~N[2024-01-15 10:00:00]}
      assert ExCellerate.eval!("dateadd(d, 3, 'hours')", scope) == ~N[2024-01-15 13:00:00]
    end

    test "adds hours across day boundary" do
      scope = %{"d" => ~N[2024-01-15 22:00:00]}
      assert ExCellerate.eval!("dateadd(d, 5, 'hours')", scope) == ~N[2024-01-16 03:00:00]
    end

    test "adds minutes to a NaiveDateTime" do
      scope = %{"d" => ~N[2024-01-15 10:00:00]}
      assert ExCellerate.eval!("dateadd(d, 90, 'minutes')", scope) == ~N[2024-01-15 11:30:00]
    end

    test "adds seconds to a NaiveDateTime" do
      scope = %{"d" => ~N[2024-01-15 10:00:00]}
      assert ExCellerate.eval!("dateadd(d, 3661, 'seconds')", scope) == ~N[2024-01-15 11:01:01]
    end

    test "adds milliseconds to a NaiveDateTime" do
      scope = %{"d" => ~N[2024-01-15 10:00:00.000]}

      assert ExCellerate.eval!("dateadd(d, 1500, 'milliseconds')", scope) ==
               ~N[2024-01-15 10:00:01.500]
    end

    test "adding sub-day units to a Date promotes to NaiveDateTime" do
      scope = %{"d" => ~D[2024-01-15]}
      result = ExCellerate.eval!("dateadd(d, 3, 'hours')", scope)
      assert %NaiveDateTime{} = result
      assert result == ~N[2024-01-15 03:00:00]
    end

    test "adds days to a NaiveDateTime (preserves time)" do
      scope = %{"d" => ~N[2024-01-15 13:30:00]}
      assert ExCellerate.eval!("dateadd(d, 5, 'days')", scope) == ~N[2024-01-20 13:30:00]
    end

    test "adds months to a NaiveDateTime (preserves time)" do
      scope = %{"d" => ~N[2024-01-15 13:30:00]}
      assert ExCellerate.eval!("dateadd(d, 2, 'months')", scope) == ~N[2024-03-15 13:30:00]
    end

    test "adds years to a NaiveDateTime (preserves time)" do
      scope = %{"d" => ~N[2024-06-15 09:00:00]}
      assert ExCellerate.eval!("dateadd(d, 1, 'years')", scope) == ~N[2025-06-15 09:00:00]
    end

    test "works with DateTime" do
      {:ok, dt, _} = DateTime.from_iso8601("2024-01-15T10:00:00Z")
      scope = %{"d" => dt}
      result = ExCellerate.eval!("dateadd(d, 5, 'days')", scope)
      assert %DateTime{} = result
      assert result.day == 20
    end

    test "adding zero returns the same date" do
      scope = %{"d" => ~D[2024-01-15]}
      assert ExCellerate.eval!("dateadd(d, 0, 'days')", scope) == ~D[2024-01-15]
    end

    test "accepts singular unit names" do
      scope = %{"d" => ~D[2024-01-15]}
      assert ExCellerate.eval!("dateadd(d, 10, 'day')", scope) == ~D[2024-01-25]
      assert ExCellerate.eval!("dateadd(d, 3, 'month')", scope) == ~D[2024-04-15]
      assert ExCellerate.eval!("dateadd(d, 2, 'year')", scope) == ~D[2026-01-15]
    end

    test "accepts singular sub-day unit names" do
      scope = %{"d" => ~N[2024-01-15 10:00:00]}
      assert ExCellerate.eval!("dateadd(d, 3, 'hour')", scope) == ~N[2024-01-15 13:00:00]
      assert ExCellerate.eval!("dateadd(d, 90, 'minute')", scope) == ~N[2024-01-15 11:30:00]
      assert ExCellerate.eval!("dateadd(d, 3661, 'second')", scope) == ~N[2024-01-15 11:01:01]
    end

    test "accepts singular millisecond unit" do
      scope = %{"d" => ~N[2024-01-15 10:00:00.000]}

      assert ExCellerate.eval!("dateadd(d, 1500, 'millisecond')", scope) ==
               ~N[2024-01-15 10:00:01.500]
    end

    test "rejects non-date first argument" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("dateadd(42, 5, 'days')")

      assert msg =~ "dateadd"
      assert msg =~ "Date"
    end

    test "rejects non-integer amount" do
      scope = %{"d" => ~D[2024-01-15]}

      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("dateadd(d, 1.5, 'days')", scope)

      assert msg =~ "dateadd"
      assert msg =~ "integer"
    end

    test "rejects invalid unit" do
      scope = %{"d" => ~D[2024-01-15]}

      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("dateadd(d, 5, 'weeks')", scope)

      assert msg =~ "dateadd"
      assert msg =~ "valid unit"
    end

    test "rejects wrong arity" do
      assert {:error, %ExCellerate.Error{type: :compiler}} =
               ExCellerate.eval("dateadd(d, 5)")

      assert {:error, %ExCellerate.Error{type: :compiler}} =
               ExCellerate.eval("dateadd(d, 5, 'days', 'extra')")
    end
  end

  # ── Guard helpers ─────────────────────────────────────────────────

  describe "guard helpers" do
    test "ensure_date_or_datetime! accepts Date" do
      assert ExCellerate.Functions.Guards.ensure_date_or_datetime!(~D[2024-01-15], "test") ==
               ~D[2024-01-15]
    end

    test "ensure_date_or_datetime! accepts NaiveDateTime" do
      assert ExCellerate.Functions.Guards.ensure_date_or_datetime!(
               ~N[2024-01-15 13:00:00],
               "test"
             ) == ~N[2024-01-15 13:00:00]
    end

    test "ensure_date_or_datetime! accepts DateTime" do
      {:ok, dt, _} = DateTime.from_iso8601("2024-01-15T13:00:00Z")

      assert ExCellerate.Functions.Guards.ensure_date_or_datetime!(dt, "test") == dt
    end

    test "ensure_date_or_datetime! rejects non-date" do
      assert_raise ExCellerate.Error, ~r/Date.*NaiveDateTime.*DateTime/, fn ->
        ExCellerate.Functions.Guards.ensure_date_or_datetime!(42, "test")
      end
    end

    test "ensure_date_unit! accepts plural units" do
      for unit <- ~w(years months days hours minutes seconds milliseconds) do
        assert ExCellerate.Functions.Guards.ensure_date_unit!(unit, "test") == unit
      end
    end

    test "ensure_date_unit! accepts singular units and normalizes to plural" do
      for {singular, plural} <- [
            {"year", "years"},
            {"month", "months"},
            {"day", "days"},
            {"hour", "hours"},
            {"minute", "minutes"},
            {"second", "seconds"},
            {"millisecond", "milliseconds"}
          ] do
        assert ExCellerate.Functions.Guards.ensure_date_unit!(singular, "test") == plural
      end
    end

    test "ensure_date_unit! rejects invalid unit" do
      assert_raise ExCellerate.Error, ~r/valid unit/, fn ->
        ExCellerate.Functions.Guards.ensure_date_unit!("weeks", "test")
      end
    end
  end

  # ── Integration / Composition ─────────────────────────────────────

  describe "composition" do
    test "extract year from a constructed date" do
      assert ExCellerate.eval!("year(date(2024, 6, 15))") == 2024
    end

    test "extract month from a constructed datetime" do
      assert ExCellerate.eval!("month(datetime(2024, 12, 25, 10, 0, 0))") == 12
    end

    test "datedif between constructed dates" do
      assert ExCellerate.eval!("datedif(date(2024, 1, 1), date(2024, 3, 1), 'days')") == 60
    end

    test "dateadd on a constructed date" do
      assert ExCellerate.eval!("dateadd(date(2024, 1, 15), 10, 'days')") == ~D[2024-01-25]
    end

    test "year of dateadd result" do
      assert ExCellerate.eval!("year(dateadd(date(2024, 12, 15), 30, 'days'))") == 2025
    end

    test "use with if" do
      scope = %{"start" => ~D[2024-01-01], "end" => ~D[2024-06-01]}

      result =
        ExCellerate.eval!(
          "if(datedif(start, end, 'months') > 3, 'long', 'short')",
          scope
        )

      assert result == "long"
    end

    test "works with scope containing dates in maps" do
      scope = %{
        "event" => %{
          "start" => ~D[2024-06-01],
          "end" => ~D[2024-06-05]
        }
      }

      assert ExCellerate.eval!("datedif(event.start, event.end, 'days')", scope) == 4
    end

    test "works with scope containing dates in lists" do
      scope = %{
        "dates" => [~D[2024-01-01], ~D[2024-06-01], ~D[2024-12-31]]
      }

      assert ExCellerate.eval!("year(dates[0])", scope) == 2024
      assert ExCellerate.eval!("month(dates[1])", scope) == 6
      assert ExCellerate.eval!("day(dates[2])", scope) == 31
    end
  end
end
