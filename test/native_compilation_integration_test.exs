# INVARIANT: any test in this file that starts the global ExCellerate.NativeCompiler
# MUST be `async: false`. It is a globally-named singleton consumed by the public
# ExCellerate.compile/2; running such tests concurrently with async tests would race
# over the shared registered name. (At test boot the global compilation strategy is
# unset/Interpreted, so the application does not auto-start a competing instance.)
defmodule ExCellerate.NativeCompilationIntegrationTest do
  use ExUnit.Case, async: false

  import ExCellerate.Test.{Eventually, NativeAssertions}

  alias ExCellerate.{Cache, NativeCompiler}
  alias ExCellerate.Test.NoNativeRegistry

  setup do
    # Reuse the global ExCellerate.Cache (started by test_helper.exs). The test
    # env disables the application's auto-start of NativeCompiler, so start it
    # here with a small purge grace for deterministic eviction.
    case ExCellerate.Cache.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    Cache.clear()
    # Same child spec the app supervisor uses (including its restart hook), so a
    # killed compiler is restarted here exactly as it would be in production.
    start_supervised!(ExCellerate.Supervisor.native_compiler_spec(native_purge_grace_ms: 20))
    Application.put_env(:excellerate, :compilation, ExCellerate.Compilation.NativeCompiled)
    on_exit(fn -> Application.delete_env(:excellerate, :compilation) end)
    :ok
  end

  describe "stale-slot recovery always terminates" do
    import ExCellerate.Test.Bounded
    import ExUnit.CaptureIO

    test "a cached expression recovers after the compiler restarts and reuses its slot" do
      {:ok, _} = ExCellerate.compile("a + 1")
      kill_native_compiler()

      # The restarted server's pool starts empty, so this takes the same slot.
      assert within(2_000, fn -> ExCellerate.eval!("a * 5", %{"a" => 10}) end) == 50
      assert within(2_000, fn -> ExCellerate.eval!("a + 1", %{"a" => 10}) end) == 11
      assert within(2_000, fn -> ExCellerate.eval!("a * 5", %{"a" => 10}) end) == 50
    end

    test "a held fun keeps working after the compiler restarts and reuses its slot" do
      {:ok, held} = ExCellerate.compile("a + 1")
      kill_native_compiler()
      {:ok, _} = ExCellerate.compile("a * 5")

      for _ <- 1..3 do
        assert within(2_000, fn -> held.(%{"a" => 10}) end) == 11
      end
    end

    test "a cached expression recovers after a graceful restart purges every module" do
      {:ok, held} = ExCellerate.compile("a + 1")
      stop_supervised!(NativeCompiler)
      start_supervised!(ExCellerate.Supervisor.native_compiler_spec(native_purge_grace_ms: 20))

      assert within(2_000, fn -> ExCellerate.eval!("a + 1", %{"a" => 10}) end) == 11
      assert within(2_000, fn -> held.(%{"a" => 10}) end) == 11
    end

    test "a stale fun left in the cache (eviction race) is replaced, not reused" do
      # Reproduces the race where a released fun is put back into the cache:
      # release the slot but leave the cache entry, then wait for the purge.
      {:ok, stale} = ExCellerate.compile("a + 1")
      NativeCompiler.release(nil, "a + 1")
      wait_until(fn -> NativeCompiler.pool_stats().free == 1 end)
      assert {:ok, ^stale} = Cache.get(nil, "a + 1")

      assert within(2_000, fn -> ExCellerate.eval!("a + 1", %{"a" => 10}) end) == 11

      # Recovery repaired the entry, so later hits run the fresh native module.
      assert {:ok, fresh} = Cache.get(nil, "a + 1")
      refute fresh == stale
      assert_native(fresh)
      assert fresh.(%{"a" => 10}) == 11
    end

    test "recovery that meets another stale fun for the same expression still terminates" do
      # `first` is bound to S0, then S0 is reused by another expression.
      {:ok, first} = ExCellerate.compile("a + 1")
      NativeCompiler.release(nil, "a + 1")
      wait_until(fn -> NativeCompiler.pool_stats().free == 1 end)
      {:ok, _} = ExCellerate.compile("b + 1")
      Cache.delete_stale(nil, "a + 1", ExCellerate.Compiled.S0)

      # The cache then holds `second`, bound to S1, which is also released.
      {:ok, second} = ExCellerate.compile("a + 1")
      NativeCompiler.release(nil, "a + 1")
      wait_until(fn -> NativeCompiler.pool_stats().free == 1 end)
      assert {:ok, ^second} = Cache.get(nil, "a + 1")

      # Recovering `first` drops nothing (the entry is bound to S1, not S0), gets
      # `second` from the cache, and `second` is stale too. That nested recovery
      # for the same expression evaluates interpreted instead of retrying.
      assert within(2_000, fn -> first.(%{"a" => 10}) end) == 11
      assert {:ok, ^second} = Cache.get(nil, "a + 1")

      # Recovering through `second` itself repairs the entry.
      assert within(2_000, fn -> second.(%{"a" => 10}) end) == 11
      assert {:ok, fresh} = Cache.get(nil, "a + 1")
      refute fresh == second
      assert within(2_000, fn -> ExCellerate.eval!("a + 1", %{"a" => 10}) end) == 11
    end

    test "a restarted compiler drops native cache entries and unloads its predecessor's modules" do
      {:ok, _} = ExCellerate.compile("a + 1")
      {:ok, _} = ExCellerate.compile("a + 2")
      mods = native_cache_mods()
      assert length(mods) == 2

      kill_native_compiler()

      assert native_cache_mods() == []
      assert %{minted: 0, free: 0, by_key: 0} = NativeCompiler.pool_stats()
      for mod <- mods, do: refute(:code.is_loaded(mod))

      # Reusing the names doesn't redefine a still-loaded module.
      warnings = capture_io(:stderr, fn -> {:ok, _} = ExCellerate.compile("a * 7") end)
      refute warnings =~ "redefining module"
    end
  end

  # Kills the compiler without running terminate/2 (so its modules stay loaded)
  # and waits for the test supervisor to restart it.
  defp kill_native_compiler do
    pid = Process.whereis(NativeCompiler)
    ref = Process.monitor(pid)
    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^ref, :process, ^pid, :killed}

    wait_until(fn ->
      new_pid = Process.whereis(NativeCompiler)
      new_pid != nil and new_pid != pid
    end)

    # The name is registered before init/1 runs, so the new process can be
    # visible while its restart cleanup is still running. A call is only served
    # once init/1 has returned, so this waits for the cleanup to finish.
    NativeCompiler.pool_stats()
  end

  defp native_cache_mods do
    :ets.select(:excellerate_cache, [{{:_, :_, :_, :"$1"}, [{:"=/=", :"$1", nil}], [:"$1"]}])
  end

  test "with the supervisor started, eval is correct and the cached fun is native" do
    assert ExCellerate.eval!("1 + 2 * 3") == 7
    {:ok, fun} = ExCellerate.compile("1 + 2 * 3")
    assert_native(fun)
  end

  test "evicting a cached entry releases its native module (slot reused)" do
    Application.put_env(:excellerate, :cache_limit, 1)
    on_exit(fn -> Application.delete_env(:excellerate, :cache_limit) end)

    assert ExCellerate.eval!("1 + 1") == 2
    assert ExCellerate.eval!("2 + 2") == 4
    # With cache_limit: 1, evaluating "2 + 2" evicts "1 + 1", which releases A's
    # native module. After the purge grace (20ms, set in setup), A's slot returns
    # to the pool, proving release + purge fired.
    wait_until(fn -> NativeCompiler.pool_stats().free >= 1 end)
  end

  describe "held compiled functions survive slot release" do
    setup do
      Application.put_env(:excellerate, :cache_limit, 1)
      on_exit(fn -> Application.delete_env(:excellerate, :cache_limit) end)
      :ok
    end

    test "a held fun stays correct after its slot is reused for another expression" do
      {:ok, held} = ExCellerate.compile("a + 1")
      assert held.(%{"a" => 10}) == 11

      # cache_limit 1: compiling "a * 5" evicts "a + 1", releasing its slot.
      {:ok, _} = ExCellerate.compile("a * 5")
      wait_until(fn -> NativeCompiler.pool_stats().free >= 1 end)

      # The freed slot is reallocated to a different expression.
      {:ok, other} = ExCellerate.compile("a - 1000")
      assert other.(%{"a" => 10}) == -990
      assert NativeCompiler.pool_stats().free == 0

      assert held.(%{"a" => 10}) == 11
    end

    test "a held fun stays correct after its module is purged but not yet reused" do
      {:ok, held} = ExCellerate.compile("a + 1")

      {:ok, _} = ExCellerate.compile("a * 5")
      wait_until(fn -> NativeCompiler.pool_stats().free >= 1 end)

      assert held.(%{"a" => 10}) == 11
    end

    test "runtime errors inside a native expression still propagate" do
      {:ok, fun} = ExCellerate.compile("1 / a")
      assert_raise ArithmeticError, fn -> fun.(%{"a" => 0}) end
    end
  end

  test "Cache.clear/0 releases the native modules of the entries it drops" do
    {:ok, _} = ExCellerate.compile("a + 1")
    {:ok, _} = ExCellerate.compile("a + 2")
    assert %{by_key: 2, free: 0} = NativeCompiler.pool_stats()

    Cache.clear()

    wait_until(fn -> match?(%{by_key: 0, free: 2}, NativeCompiler.pool_stats()) end)
  end

  test "the Interpreted strategy uses the interpreter" do
    Application.put_env(:excellerate, :compilation, ExCellerate.Compilation.Interpreted)
    {:ok, fun} = ExCellerate.compile("3 + 4")
    assert Function.info(fun)[:module] == :erl_eval
    assert fun.(%{}) == 7
  end

  test "a per-registry Interpreted strategy overrides the global default" do
    # Global is native (set in setup); the registry opts out.
    {:ok, reg_fun} = ExCellerate.compile("5 + 6", NoNativeRegistry)
    assert Function.info(reg_fun)[:module] == :erl_eval
    assert reg_fun.(%{}) == 11

    # Default (no registry) path is still native.
    {:ok, default_fun} = ExCellerate.compile("5 + 6")

    assert_native(default_fun)
  end
end

defmodule ExCellerate.NativeCompilationFallbackTest do
  # The :excellerate application runs ExCellerate.Supervisor (an empty
  # DynamicSupervisor); NativeCompiler is started lazily on first native use.
  # These tests cover that lazy start and the graceful fallback when the compiler
  # call exits (the TOCTOU race). async: false — they touch the global singletons.
  use ExUnit.Case, async: false

  import ExCellerate.Test.NativeAssertions
  import ExUnit.CaptureLog

  alias ExCellerate.Test.WarnFlags

  setup do
    case ExCellerate.Cache.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    ExCellerate.Cache.clear()
    stop_native_compiler()
    Application.put_env(:excellerate, :compilation, ExCellerate.Compilation.NativeCompiled)

    on_exit(fn ->
      Application.delete_env(:excellerate, :compilation)
      stop_native_compiler()
    end)

    :ok
  end

  # Ensure no NativeCompiler is registered: terminate a lazily-started one under
  # the app supervisor (a :permanent child would restart on GenServer.stop), or
  # kill anything else registered under the name (e.g. a test's dummy process).
  defp stop_native_compiler do
    case Process.whereis(ExCellerate.NativeCompiler) do
      nil ->
        :ok

      pid ->
        case DynamicSupervisor.terminate_child(ExCellerate.Supervisor, pid) do
          :ok -> :ok
          {:error, :not_found} -> Process.exit(pid, :kill)
        end

        :ok
    end
  end

  test "compile/2 lazily starts NativeCompiler and compiles natively under NativeCompiled" do
    refute Process.whereis(ExCellerate.NativeCompiler)

    {:ok, fun} = ExCellerate.compile("7 + 8")
    assert fun.(%{}) == 15
    assert_native(fun)

    # The compiler was started on demand — no manual supervision wiring.
    assert Process.whereis(ExCellerate.NativeCompiler)
  end

  test "falls back to interpreter if NativeCompiler name is owned by a non-GenServer (race safety)" do
    # Simulate the TOCTOU race: build_fun's Process.whereis sees a LIVE process
    # registered under the NativeCompiler name, but the subsequent GenServer.call
    # exits. The dummy stays alive (so whereis returns its pid), then on receiving
    # the GenServer.call it exits without replying. Because the caller monitors the
    # callee for the duration of the call, this makes GenServer.call exit with
    # {:noproc/:EXIT, ...} *immediately* (no 5s timeout) — deterministic and fast.
    # With the :exit catch in build_fun, eval must still succeed via the interpreter.
    ExCellerate.Cache.clear()

    parent = self()

    pid =
      spawn(fn ->
        Process.register(self(), ExCellerate.NativeCompiler)
        send(parent, :registered)

        # Wait for the GenServer.call ($gen_call) message, then die without
        # replying so the caller's call exits at once.
        receive do
          {:"$gen_call", _from, _request} -> exit(:simulated_crash)
        end
      end)

    assert_receive :registered
    # Sanity: the name is owned by our live dummy at the whereis check.
    assert Process.whereis(ExCellerate.NativeCompiler) == pid

    # No caller crash; result is correct via the interpreted fallback, and the
    # fallback is logged (once per VM).
    WarnFlags.reset(:excellerate_native_exit_warned)
    log = capture_log(fn -> assert ExCellerate.eval!("2 + 3") == 5 end)
    assert log =~ "NativeCompiler exited during compilation"
    assert log =~ "simulated_crash"

    on_exit(fn ->
      if p = Process.whereis(ExCellerate.NativeCompiler), do: Process.exit(p, :kill)
    end)
  end
end
