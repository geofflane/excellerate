defmodule ExCellerate.Functions.Math.Ln do
  @moduledoc false
  # Internal: Implements the 'ln' function — natural logarithm (base e).
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "ln"
  @impl true
  def arity, do: 1

  @impl true
  def call([n]) when is_number(n), do: :math.log(n)

  def call([other]) do
    raise ExCellerate.Error,
      message: "#{name()} expects a number, got: #{inspect(other)}",
      type: :runtime
  end
end
