defmodule ExCellerate.Test.Eventually do
  @moduledoc false
  # Polls instead of sleeping a fixed interval past some asynchronous event
  # (e.g. a grace-period purge), so tests neither flake on a slow machine nor
  # wait longer than they need to.

  import ExUnit.Assertions, only: [flunk: 1]

  @interval_ms 10

  @doc "Waits until `fun` returns truthy, failing after about `timeout_ms`."
  def wait_until(fun, timeout_ms \\ 2_000) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_wait_until(fun, deadline)
  end

  defp do_wait_until(fun, deadline) do
    cond do
      fun.() ->
        :ok

      System.monotonic_time(:millisecond) >= deadline ->
        flunk("condition not met in time")

      true ->
        receive(after: (@interval_ms -> do_wait_until(fun, deadline)))
    end
  end
end
