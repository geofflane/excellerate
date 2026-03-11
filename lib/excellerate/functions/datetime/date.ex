defmodule ExCellerate.Functions.DateTime.Date do
  @moduledoc """
  Creates a `Date` from year, month, and day integers.

  ## Examples

      date(2024, 1, 15)  → ~D[2024-01-15]
      date(2024, 2, 29)  → ~D[2024-02-29]
  """
  @behaviour ExCellerate.Function

  alias Date, as: D
  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "date"
  @impl true
  def arity, do: 3

  @impl true
  def call([year, month, day]) do
    ensure_integer!(year, name())
    ensure_integer!(month, name())
    ensure_integer!(day, name())

    case D.new(year, month, day) do
      {:ok, date} ->
        date

      {:error, _} ->
        raise ExCellerate.Error,
          message: "'#{name()}' received invalid date: #{year}-#{month}-#{day}",
          type: :runtime
    end
  end
end
