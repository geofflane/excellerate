defmodule ExCellerate.Functions.General.Ifs do
  @moduledoc """
  Evaluates a series of condition/value pairs and returns the value for
  the first truthy condition.

  Arguments must be provided in pairs: `condition1, value1, condition2,
  value2, ...`. Use `true` as the final condition to provide a default.
  Returns `null` if no conditions are met.

  ## Examples

      ifs(score > 90, 'A', score > 80, 'B', true, 'C')
        → 'A' (when score is 95)
        → 'B' (when score is 85)
        → 'C' (when score is 70)

      ifs(x > 10, 'big', x > 5, 'medium')
        → null (when x is 1)
  """
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "ifs"
  @impl true
  def arity, do: :any

  @impl true
  def call(args) do
    ensure_even_args!(args, name())
    match(args)
  end

  defp match([]), do: nil

  defp match([condition, value | rest]) do
    if condition do
      value
    else
      match(rest)
    end
  end
end
