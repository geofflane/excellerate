defmodule ExCellerate.Functions.Math.Log10 do
  @moduledoc """
  Returns the base-10 logarithm of a number.

  ## Examples

      log10(100)  → 2.0
      log10(1000) → 3.0
  """
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "log10"
  @impl true
  def arity, do: 1

  @impl true
  def call([n]) do
    ensure_number!(n, name())
    :math.log10(n)
  end
end
