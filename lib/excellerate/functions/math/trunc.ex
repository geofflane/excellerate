defmodule ExCellerate.Functions.Math.Trunc do
  @moduledoc false
  # Internal: Implements the 'trunc' function — truncates toward zero.
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "trunc"
  @impl true
  def arity, do: 1

  @impl true
  def call([n]) do
    ensure_number!(n, name())
    trunc(n)
  end
end
