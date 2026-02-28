defmodule ExCellerate.Functions.General.Switch do
  @moduledoc false
  # Internal: Implements the 'switch' function — multi-way value matching.
  # Usage: switch(expr, case1, val1, case2, val2, ..., [default])
  # If the number of remaining args after expr is odd, the last arg is the default.
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "switch"
  @impl true
  def arity, do: :any

  @impl true
  def call([expr | pairs]) do
    match(expr, pairs)
  end

  defp match(_expr, []), do: nil
  defp match(_expr, [default]), do: default

  defp match(expr, [case_val, result | rest]) do
    if expr == case_val do
      result
    else
      match(expr, rest)
    end
  end
end
