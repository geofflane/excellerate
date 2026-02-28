defmodule ExCellerate.Functions.Math.Sqrt do
  @moduledoc false
  # Internal: Implements the 'sqrt' function — returns the square root.
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "sqrt"
  @impl true
  def arity, do: 1

  @impl true
  def call([n]) when is_number(n) and n >= 0, do: :math.sqrt(n)

  def call([n]) when is_number(n) do
    raise ExCellerate.Error,
      message: "#{name()} requires a non-negative number, got #{n}",
      type: :runtime
  end

  def call([other]) do
    raise ExCellerate.Error,
      message: "#{name()} expects a number, got: #{inspect(other)}",
      type: :runtime
  end
end
