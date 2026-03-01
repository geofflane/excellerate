defmodule ExCellerate.Functions.General.Ifs do
  @moduledoc false
  # Internal: Implements the 'ifs' function — multi-condition matching.
  # Usage: ifs(cond1, val1, cond2, val2, ...)
  # Returns the value for the first truthy condition.
  # Use `true` as the final condition for a default value.
  # Returns nil if no conditions are met. Raises if args are not paired.
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
