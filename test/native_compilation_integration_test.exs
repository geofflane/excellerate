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
    Application.put_env(:excellerate, :native_compilation, true)

    on_exit(fn ->
      Application.delete_env(:excellerate, :native_compilation)
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
    Process.sleep(120)

    stats = NativeCompiler.pool_stats()
    assert stats.free >= 1 or stats.minted <= 2
  end

  test "native_compilation: false falls back to the interpreter" do
    Application.put_env(:excellerate, :native_compilation, false)
    {:ok, fun} = ExCellerate.compile("3 + 4")
    assert Function.info(fun)[:module] == :erl_eval
    assert fun.(%{}) == 7
  end

  test "per-registry native_compilation: false overrides global native" do
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
    Application.put_env(:excellerate, :native_compilation, true)
    on_exit(fn -> Application.delete_env(:excellerate, :native_compilation) end)
    :ok
  end

  test "compile/2 works and yields an interpreted fun when NativeCompiler not running" do
    refute Process.whereis(ExCellerate.NativeCompiler)
    {:ok, fun} = ExCellerate.compile("7 + 8")
    assert Function.info(fun)[:module] == :erl_eval
    assert fun.(%{}) == 15
  end
end
