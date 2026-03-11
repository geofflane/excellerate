defmodule ExCellerate.Functions.DateTime.Now do
  @moduledoc """
  Returns the current date and time as a `NaiveDateTime`.

  ## Examples

      now()  → ~N[2024-01-15 13:30:45]  (current date and time)
  """
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "now"
  @impl true
  def arity, do: 0

  @impl true
  def call([]) do
    NaiveDateTime.utc_now()
  end
end
