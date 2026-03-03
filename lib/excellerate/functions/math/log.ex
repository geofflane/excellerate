defmodule ExCellerate.Functions.Math.Log do
  @moduledoc """
  Returns the logarithm of a value in the specified base.

  ## Examples

      log(8, 2)    → 3.0
      log(100, 10) → 2.0
  """
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "log"
  @impl true
  def arity, do: 2

  @impl true
  def call([value, base]) do
    ensure_number!(value, name())
    ensure_number!(base, name())
    :math.log(value) / :math.log(base)
  end
end
