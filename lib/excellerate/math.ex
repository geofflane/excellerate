defmodule ExCellerate.Math do
  @moduledoc false
  # Internal: Utility module for mathematical operations like factorial.

  # Default cap on the factorial operand. Without it, a tiny input such as
  # `999999999!` builds an astronomically large bignum and never returns,
  # exhausting CPU and memory. Override with
  # `config :excellerate, max_factorial_input: <n>`.
  @default_max_input 10_000

  # Calculates the factorial of a non-negative integer.
  @spec factorial(term()) :: pos_integer()
  def factorial(n) when is_integer(n) and n >= 0 do
    max_input = Application.get_env(:excellerate, :max_factorial_input, @default_max_input)

    if n > max_input do
      raise ExCellerate.Error,
        message: "factorial argument too large (#{n}, limit #{max_input})",
        type: :runtime
    end

    fac(n, 1)
  end

  def factorial(other) do
    raise ExCellerate.Error,
      message: "factorial requires a non-negative integer, got #{inspect(other)}",
      type: :runtime
  end

  # Tail-recursive accumulator so deep inputs do not grow the call stack.
  defp fac(0, acc), do: acc
  defp fac(n, acc), do: fac(n - 1, acc * n)
end
