defmodule ExCellerate.Functions.Math.Log do
  @moduledoc false
  # Internal: Implements the 'log' function — logarithm with specified base.
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "log"
  @impl true
  def arity, do: 2

  @impl true
  def call([value, base]) when is_number(value) and is_number(base) do
    :math.log(value) / :math.log(base)
  end

  def call([value, base]) do
    raise ExCellerate.Error,
      message: "#{name()} expects two numbers, got: #{inspect(value)}, #{inspect(base)}",
      type: :runtime
  end
end
