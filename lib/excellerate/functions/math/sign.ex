defmodule ExCellerate.Functions.Math.Sign do
  @moduledoc false
  # Internal: Implements the 'sign' function — returns -1, 0, or 1.
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "sign"
  @impl true
  def arity, do: 1

  @impl true
  def call([n]) do
    ensure_number!(n, name())

    cond do
      n > 0 -> 1
      n < 0 -> -1
      true -> 0
    end
  end
end
