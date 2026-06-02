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
#   2. Re-evaluating a bounded, cached set of expressions does NOT grow the atom
#      table (cache hits never recompile) -- the steady-state pattern.
#
# NOTE on atoms: the slot pool bounds live module CODE/memory (minted <= limit),
# but `Module.create/3` interns ~1 permanent atom PER CALL even when the module
# name is reused. So each DISTINCT natively-compiled expression costs ~1 atom.
# Native compilation is therefore intended for bounded/trusted expression sets
# (cache sized to hold them); it is NOT atom-safe for unbounded/untrusted input,
# which should run with the Interpreted strategy (the interpreted path leaks
# no atoms). The third test below characterizes this cost so it can't regress
# unnoticed.
defmodule ExCellerate.NativeCompilationSafetyTest do
  use ExUnit.Case, async: false

  alias ExCellerate.{Cache, NativeCompiler}

  # Reuses the global ExCellerate.Cache (from test_helper) and starts a
  # NativeCompiler with per-test pool limit + grace. The test env disables the
  # application's auto-start of NativeCompiler, so there is no competing instance.
  defp setup_supervisor(opts) do
    cache_limit = Keyword.fetch!(opts, :cache_limit)
    module_limit = Keyword.fetch!(opts, :module_limit)
    grace_ms = Keyword.fetch!(opts, :grace_ms)

    case ExCellerate.Cache.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    Application.put_env(:excellerate, :compilation, ExCellerate.Compilation.NativeCompiled)
    Application.put_env(:excellerate, :cache_limit, cache_limit)

    start_supervised!(
      {NativeCompiler, native_module_limit: module_limit, native_purge_grace_ms: grace_ms}
    )

    Cache.clear()

    on_exit(fn ->
      Application.delete_env(:excellerate, :compilation)
      Application.delete_env(:excellerate, :cache_limit)
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

  test "re-evaluating a bounded, cached set of expressions does not grow the atom table" do
    # The real steady-state pattern: a fixed set of formulas, evaluated many
    # times. cache_limit > set size, so each formula is compiled exactly ONCE;
    # every subsequent eval is a cache hit that returns the stored function and
    # never recompiles. No recompile => no Module.create => no new atoms. This is
    # the property that actually matters for production use (e.g. a game loop
    # evaluating the same formulas hundreds of times).
    :ok = setup_supervisor(cache_limit: 1000, module_limit: 1000, grace_ms: 1000)

    formulas = for i <- 1..50, do: "#{i} * 2 + 1"

    # Compile each once (warm the cache + mint one native module per formula).
    for f <- formulas, do: ExCellerate.eval!(f)
    Process.sleep(50)

    before = :erlang.system_info(:atom_count)

    # Evaluate the SAME 50 formulas 200 times each (10_000 evals, all cache hits).
    for _ <- 1..200, f <- formulas do
      ExCellerate.eval!(f)
    end

    delta = :erlang.system_info(:atom_count) - before

    assert delta <= 5,
           "re-evaluating a cached bounded set grew atom_count by #{delta}; " <>
             "expected ~0 (cache hits must not recompile)"
  end

  test "each distinct natively-compiled expression costs ~one atom (Module.create) — characterization" do
    # Honest characterization (NOT a 'safety' guarantee): the slot pool bounds
    # live module code/memory, but Module.create interns ~1 atom per call, so the
    # atom table grows ~1 per DISTINCT expression that is natively compiled. This
    # is fine for bounded/trusted sets and is why native must stay OFF for
    # unbounded/untrusted input. This test pins the behavior so a regression
    # (e.g. an accidental per-eval recompile) or a future Module.create fix is
    # noticed.
    :ok = setup_supervisor(cache_limit: 1000, module_limit: 1000, grace_ms: 1000)

    before = :erlang.system_info(:atom_count)
    n = 500
    for i <- 1..n, do: assert(ExCellerate.eval!("3 + #{i}") == 3 + i)

    delta = :erlang.system_info(:atom_count) - before

    # Grows roughly one atom per distinct native compile (observed ~1.0/compile);
    # the lower bound documents that it is proportional, not magically bounded.
    assert delta >= div(n, 2),
           "expected ~#{n} new atoms (≈one per distinct native compile), got #{delta}"

    # The slot pool still bounds live module-name atoms to its configured limit.
    assert NativeCompiler.pool_stats().minted <= 1000
  end
end
