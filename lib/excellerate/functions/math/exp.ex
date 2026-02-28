defmodule ExCellerate.Functions.Math.Exp do
  @moduledoc false
  # Internal: Implements the 'exp' function — e raised to the power.
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "exp"
  @impl true
  def arity, do: 1

  @impl true
  def call([n]) when is_number(n), do: :math.exp(n)

  def call([other]) do
    raise ExCellerate.Error,
      message: "#{name()} expects a number, got: #{inspect(other)}",
      type: :runtime
  end
end
