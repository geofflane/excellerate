defmodule ExCellerate.Functions.DateTime.Today do
  @moduledoc """
  Returns the current date as a `Date`.

  ## Examples

      today()  → ~D[2024-01-15]  (current date)
  """
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "today"
  @impl true
  def arity, do: 0

  @impl true
  def call([]) do
    Date.utc_today()
  end
end
