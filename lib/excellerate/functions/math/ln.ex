defmodule ExCellerate.Functions.Math.Ln do
  @moduledoc false
  # Internal: Implements the 'ln' function — natural logarithm (base e).
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
