# INVARIANT: any test in this file that starts the global ExCellerate.NativeCompiler,
# or stops/restarts the global ExCellerate.Cache, MUST be `async: false`. These are
# globally-named singletons consumed by the public ExCellerate.compile/2; running such
# tests concurrently with async tests causes races over the shared registered names.
defmodule ExCellerate.NativeCompilationIntegrationTest do
  use ExUnit.Case, async: false

  alias ExCellerate.{Cache, NativeCompiler}
  alias ExCellerate.Test.NoNativeRegistry

  setup do
    # test_helper.exs starts a global ExCellerate.Cache; stop it so the
    # supervisor can own both children cleanly. Restore it on exit so other
    # (randomly ordered) test files still find a running Cache.
    if pid = Process.whereis(ExCellerate.Cache), do: GenServer.stop(pid)

    # Small grace so the eviction/release purge fires quickly and the test
    # stays deterministic without a long sleep.
    Application.put_env(:excellerate, :native_purge_grace_ms, 20)
    start_supervised!(ExCellerate.Supervisor)
    Cache.clear()
    Application.put_env(:excellerate, :compilation, ExCellerate.Compilation.NativeCompiled)

    on_exit(fn ->
      Application.delete_env(:excellerate, :compilation)
      Application.delete_env(:excellerate, :native_purge_grace_ms)

      # start_supervised tears down the supervised Cache; bring the global one
      # back up for subsequent test files.
      case ExCellerate.Cache.start_link() do
        {:ok, _pid} -> :ok
        {:error, {:already_started, _pid}} -> :ok
      end
    end)

    :ok
  end

  test "with the supervisor started, eval is correct and the cached fun is native" do
    assert ExCellerate.eval!("1 + 2 * 3") == 7
    {:ok, fun} = ExCellerate.compile("1 + 2 * 3")
    assert Function.info(fun)[:type] == :external

    assert Function.info(fun)[:module]
           |> Atom.to_string()
           |> String.starts_with?("Elixir.ExCellerate.Compiled.S")
  end

  test "evicting a cached entry releases its native module (slot reused)" do
    Application.put_env(:excellerate, :cache_limit, 1)
    on_exit(fn -> Application.delete_env(:excellerate, :cache_limit) end)

    assert ExCellerate.eval!("1 + 1") == 2
    assert ExCellerate.eval!("2 + 2") == 4
    # With cache_limit: 1, evaluating "2 + 2" evicts "1 + 1", which releases A's
    # native module. After the purge grace (20ms, set in setup), A's slot returns
    # to the pool. Sleep past the grace, then assert the slot was actually reclaimed
    # (proves release + purge fired, not a trivially-true condition).
    Process.sleep(120)

    stats = NativeCompiler.pool_stats()
    assert stats.free >= 1
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

    assert Function.info(default_fun)[:module]
           |> Atom.to_string()
           |> String.starts_with?("Elixir.ExCellerate.Compiled.S")
  end
end

defmodule ExCellerate.NativeCompilationFallbackTest do
  # Separate module WITHOUT the supervisor so NativeCompiler is not running:
  # compile/2 must still work and yield an interpreted (:erl_eval) fun.
  use ExUnit.Case, async: false

  setup do
    # Cache may or may not be running (test_helper starts it). Ensure
    # NativeCompiler is NOT running for this test.
    if pid = Process.whereis(ExCellerate.NativeCompiler) do
      GenServer.stop(pid)
    end

    case ExCellerate.Cache.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    ExCellerate.Cache.clear()
    Application.put_env(:excellerate, :compilation, ExCellerate.Compilation.NativeCompiled)
    on_exit(fn -> Application.delete_env(:excellerate, :compilation) end)
    :ok
  end

  test "compile/2 works and yields an interpreted fun when NativeCompiler not running" do
    refute Process.whereis(ExCellerate.NativeCompiler)
    {:ok, fun} = ExCellerate.compile("7 + 8")
    assert Function.info(fun)[:module] == :erl_eval
    assert fun.(%{}) == 15
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

    # No caller crash; result is correct via the interpreted fallback.
    assert ExCellerate.eval!("2 + 3") == 5

    on_exit(fn ->
      if p = Process.whereis(ExCellerate.NativeCompiler), do: Process.exit(p, :kill)
    end)
  end
end
