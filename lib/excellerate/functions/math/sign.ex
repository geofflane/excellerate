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
  def call([n]) when is_number(n) and n > 0, do: 1
  def call([n]) when is_number(n) and n < 0, do: -1
  def call([n]) when is_number(n), do: 0
  def call([other]), do: ensure_number!(other, name())
end
