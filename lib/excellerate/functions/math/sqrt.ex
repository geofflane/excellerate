defmodule ExCellerate.Functions.Math.Sqrt do
  @moduledoc false
  # Internal: Implements the 'sqrt' function — returns the square root.
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "sqrt"
  @impl true
  def arity, do: 1

  @impl true
  def call([n]) do
    ensure_number!(n, name())

    if n < 0 do
      raise ExCellerate.Error,
        message: "#{name()} requires a non-negative number, got #{n}",
        type: :runtime
    end

    :math.sqrt(n)
  end
end
