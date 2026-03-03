defmodule ExCellerate.Functions.General.Switch do
  @moduledoc """
  Matches an expression against a series of case/value pairs and returns
  the value for the first match.

  Arguments after the expression are provided in pairs: `case1, value1,
  case2, value2, ...`. If the total number of remaining arguments is odd,
  the last argument is used as a default. Returns `null` if nothing
  matches and no default is given.

  ## Examples

      switch(status, 'active', 'Running', 'paused', 'Paused', 'Unknown')
        → 'Running' (when status is 'active')
        → 'Unknown' (when status is 'archived')

      switch('B', 'A', 1, 'B', 2, 'C', 3) → 2
      switch('D', 'A', 1, 'B', 2)          → null
  """
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
