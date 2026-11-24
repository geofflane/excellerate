defmodule ExCellerate.Test.Bounded do
  @moduledoc false
  # Runs `fun` in a task and fails the test if it doesn't return within
  # `timeout_ms`. Guards regression tests for hangs and super-linear blow-ups so
  # a regression fails fast instead of wedging the suite. Bounds are chosen
  # orders of magnitude above the fixed cost, so they don't flake on slow CI.

  import ExUnit.Assertions, only: [flunk: 1]

  def within(timeout_ms, fun) when is_function(fun, 0) do
    task = Task.async(fun)

    case Task.yield(task, timeout_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} -> result
      {:exit, reason} -> exit(reason)
      nil -> flunk("did not complete within #{timeout_ms}ms")
    end
  end
end
