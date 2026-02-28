defmodule ExCellerate.Functions.Math.Log10 do
  @moduledoc false
  # Internal: Implements the 'log10' function — base-10 logarithm.
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "log10"
  @impl true
  def arity, do: 1

  @impl true
  def call([n]) when is_number(n), do: :math.log10(n)

  def call([other]) do
    raise ExCellerate.Error,
      message: "#{name()} expects a number, got: #{inspect(other)}",
      type: :runtime
  end
end
