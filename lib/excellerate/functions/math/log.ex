defmodule ExCellerate.Functions.Math.Log do
  @moduledoc false
  # Internal: Implements the 'log' function — logarithm with specified base.
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "log"
  @impl true
  def arity, do: 2

  @impl true
  def call([value, base]) when is_number(value) and is_number(base) do
    :math.log(value) / :math.log(base)
  end

  def call([value, base]) do
    ensure_number!(value, name())
    ensure_number!(base, name())
  end
end
