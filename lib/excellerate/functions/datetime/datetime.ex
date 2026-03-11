defmodule ExCellerate.Functions.DateTime.DateTime do
  @moduledoc """
  Creates a `NaiveDateTime` from year, month, day, and optional hour,
  minute, and second integers.

  When hour, minute, or second are omitted they default to `0`.

  ## Examples

      datetime(2024, 1, 15, 13, 30, 45)  → ~N[2024-01-15 13:30:45]
      datetime(2024, 1, 15)              → ~N[2024-01-15 00:00:00]
      datetime(2024, 1, 15, 13)          → ~N[2024-01-15 13:00:00]
      datetime(2024, 1, 15, 13, 30)      → ~N[2024-01-15 13:30:00]
  """
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "datetime"
  @impl true
  def arity, do: 3..6

  @impl true
  def call([year, month, day]) do
    call([year, month, day, 0, 0, 0])
  end

  def call([year, month, day, hour]) do
    call([year, month, day, hour, 0, 0])
  end

  def call([year, month, day, hour, minute]) do
    call([year, month, day, hour, minute, 0])
  end

  def call([year, month, day, hour, minute, second]) do
    ensure_integer!(year, name())
    ensure_integer!(month, name())
    ensure_integer!(day, name())
    ensure_integer!(hour, name())
    ensure_integer!(minute, name())
    ensure_integer!(second, name())

    case NaiveDateTime.new(year, month, day, hour, minute, second) do
      {:ok, ndt} ->
        ndt

      {:error, _} ->
        raise ExCellerate.Error,
          message:
            "'#{name()}' received invalid datetime: #{year}-#{month}-#{day} #{hour}:#{minute}:#{second}",
          type: :runtime
    end
  end
end
