defmodule ExCellerate.Functions.Math.Ln do
  @moduledoc """
  Returns the natural logarithm (base *e*) of a number.

  ## Examples

      ln(1)           → 0.0
      ln(2.718281828) → 1.0 (approximately)
  """
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "ln"
  @impl true
  def arity, do: 1

  @impl true
  def call([n]) do
    ensure_number!(n, name())
    :math.log(n)
  end
end
