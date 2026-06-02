# INVARIANT: any test in this file that starts the global ExCellerate.NativeCompiler
# MUST be `async: false`. It is a globally-named singleton consumed by the public
# ExCellerate.compile/2; running such tests concurrently with async tests would race
# over the shared registered name. (At test boot the global compilation strategy is
# unset/Interpreted, so the application does not auto-start a competing instance.)
defmodule ExCellerate.NativeCompilationIntegrationTest do
  use ExUnit.Case, async: false

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
    start_supervised!({NativeCompiler, native_purge_grace_ms: 20})
    Application.put_env(:excellerate, :compilation, ExCellerate.Compilation.NativeCompiled)
    on_exit(fn -> Application.delete_env(:excellerate, :compilation) end)
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
  # The :excellerate application runs ExCellerate.Supervisor (an empty
  # DynamicSupervisor); NativeCompiler is started lazily on first native use.
  # These tests cover that lazy start and the graceful fallback when the compiler
  # call exits (the TOCTOU race). async: false — they touch the global singletons.
  use ExUnit.Case, async: false

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
    assert Function.info(fun)[:type] == :external

    assert Function.info(fun)[:module]
           |> Atom.to_string()
           |> String.starts_with?("Elixir.ExCellerate.Compiled.S")

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

    # No caller crash; result is correct via the interpreted fallback.
    assert ExCellerate.eval!("2 + 3") == 5

    on_exit(fn ->
      if p = Process.whereis(ExCellerate.NativeCompiler), do: Process.exit(p, :kill)
    end)
  end
end
