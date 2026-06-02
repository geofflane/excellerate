# INVARIANT: this module MUST be `async: false`. It starts the globally-named
# ExCellerate.NativeCompiler + stops/restarts the global ExCellerate.Cache and
# consumes them through the public ExCellerate API. Running concurrently with
# async tests would race over those shared registered names.
#
# These tests validate two safety properties of the native-compilation design:
#   1. Under heavy concurrent eval + eviction/purge churn, NO caller process
#      crashes and ALL results are correct (the grace-period + soft_purge + the
#      build_fun `:exit` catch keep callers alive while modules are purged out
#      from under them).
#   2. The atom table stays bounded: compiling many DISTINCT expressions with a
#      small native_module_limit reuses the pool's slot atoms instead of minting
#      a fresh module-name atom per expression (no atom-exhaustion leak).
defmodule ExCellerate.NativeCompilationSafetyTest do
  use ExUnit.Case, async: false

  alias ExCellerate.{Cache, NativeCompiler}

  # Mirrors the stop/restore-Cache + supervisor-start mechanics from
  # test/native_compilation_integration_test.exs. Each test overrides the
  # limits/grace via Application.put_env BEFORE start_supervised! so the
  # supervisor's children pick them up.
  defp setup_supervisor(opts) do
    cache_limit = Keyword.fetch!(opts, :cache_limit)
    module_limit = Keyword.fetch!(opts, :module_limit)
    grace_ms = Keyword.fetch!(opts, :grace_ms)

    # test_helper.exs starts a global ExCellerate.Cache; stop it so the
    # supervisor can own both children cleanly. Restored on exit below.
    if pid = Process.whereis(ExCellerate.Cache), do: GenServer.stop(pid)

    Application.put_env(:excellerate, :native_compilation, true)
    Application.put_env(:excellerate, :cache_limit, cache_limit)
    Application.put_env(:excellerate, :native_module_limit, module_limit)
    Application.put_env(:excellerate, :native_purge_grace_ms, grace_ms)

    start_supervised!(ExCellerate.Supervisor)
    Cache.clear()

    on_exit(fn ->
      Application.delete_env(:excellerate, :native_compilation)
      Application.delete_env(:excellerate, :cache_limit)
      Application.delete_env(:excellerate, :native_module_limit)
      Application.delete_env(:excellerate, :native_purge_grace_ms)

      # start_supervised tears down the supervised Cache; bring the global one
      # back up for subsequent (randomly ordered) test files.
      case ExCellerate.Cache.start_link() do
        {:ok, _pid} -> :ok
        {:error, {:already_started, _pid}} -> :ok
      end
    end)

    :ok
  end

  test "concurrent eval + eviction/purge churn: no crashes, all results correct" do
    # Tiny cache_limit + tiny module_limit + tiny grace => the cache constantly
    # evicts -> releases -> soft-purges native modules WHILE other workers are
    # compiling/evaluating against the same pool. This is the stress that must
    # not crash callers.
    :ok = setup_supervisor(cache_limit: 8, module_limit: 8, grace_ms: 10)

    workers = 50
    iterations = 100

    tasks =
      for w <- 1..workers do
        Task.async(fn ->
          for n <- 1..iterations do
            a = w + n
            b = n * 2

            # SHARED expressions (cache hits + dedup across workers), with the
            # scope varied so results genuinely depend on input.
            assert ExCellerate.eval!("a + b", %{"a" => a, "b" => b}) == a + b
            assert ExCellerate.eval!("a * 2", %{"a" => a}) == a * 2

            # DISTINCT expression per worker/iteration: forces a fresh compile
            # and drives eviction/purge churn against the bounded pool.
            assert ExCellerate.eval!("#{w} + #{n}") == w + n
          end

          :done
        end)
      end

    # If any worker crashed (e.g. a GenServer.call exit leaked through), the
    # corresponding await raises and the test fails. A clean :done from every
    # worker proves no caller crashed AND every assertion held.
    results = Task.await_many(tasks, 30_000)
    assert results == List.duplicate(:done, workers)
  end

  test "atom count stays bounded over many distinct expressions (slot reuse, no leak)" do
    :ok = setup_supervisor(cache_limit: 16, module_limit: 16, grace_ms: 5)

    # Warm up: mint the initial slot atoms + any one-time machinery atoms so
    # they don't count against the measured delta below.
    for i <- 1..20 do
      assert ExCellerate.eval!("1 + #{i}") == 1 + i
    end

    # Let the eviction-triggered purges settle so slots return to the pool.
    Process.sleep(100)

    before = :erlang.system_info(:atom_count)

    # Evaluate a LARGE number of DISTINCT expressions. With cache_limit and
    # native_module_limit both 16, eviction + purge recycles the ~16 slot atoms
    # rather than minting one per expression. If module-name atoms were minted
    # per distinct expression, this delta would be ~2000+; the small bound below
    # proves the pool reuses slot atoms.
    distinct = 2000

    for i <- 1..distinct do
      assert ExCellerate.eval!("1 + #{i}") == 1 + i
      # Periodically let purges free slots back to the pool under churn.
      if rem(i, 200) == 0, do: Process.sleep(5)
    end

    after_count = :erlang.system_info(:atom_count)
    delta = after_count - before

    assert delta < 200,
           "atom_count grew by #{delta} over #{distinct} distinct expressions; " <>
             "expected a small bounded delta (slot reuse), not proportional growth"

    # Sanity: the pool never minted more module-name atoms than its limit.
    stats = NativeCompiler.pool_stats()
    assert stats.minted <= 16
  end
end
