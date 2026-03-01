defmodule ExCellerate.CacheTest do
  # async: false because these tests share a global ETS table.
  use ExUnit.Case

  alias ExCellerate.Test.LimitRegistry
  alias ExCellerate.Test.NoCacheRegistry

  setup do
    case ExCellerate.Cache.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    ExCellerate.Cache.clear()
    :ok
  end

  test "caching respects size limits" do
    LimitRegistry.eval!("1")
    LimitRegistry.eval!("2")
    LimitRegistry.eval!("3")

    count =
      :ets.select_count(:excellerate_cache, [
        {{{LimitRegistry, :_}, :_, :_}, [], [true]}
      ])

    assert count <= 2
  end

  test "LRU eviction removes least recently used entry" do
    # Use Cache.put/get directly with deterministic values.
    # LimitRegistry has cache_limit: 2.
    ExCellerate.Cache.put(LimitRegistry, "a", :val_a)
    ExCellerate.Cache.put(LimitRegistry, "b", :val_b)

    # Touch "a" to make it most-recently-used
    assert {:ok, :val_a} = ExCellerate.Cache.get(LimitRegistry, "a")

    # Insert a third — should evict "b" (least recently used)
    ExCellerate.Cache.put(LimitRegistry, "c", :val_c)

    assert {:ok, :val_a} = ExCellerate.Cache.get(LimitRegistry, "a")
    assert :error = ExCellerate.Cache.get(LimitRegistry, "b")
    assert {:ok, :val_c} = ExCellerate.Cache.get(LimitRegistry, "c")
  end

  test "LRU eviction keeps most recently inserted when no re-access" do
    ExCellerate.Cache.put(LimitRegistry, "x", :val_x)
    ExCellerate.Cache.put(LimitRegistry, "y", :val_y)
    ExCellerate.Cache.put(LimitRegistry, "z", :val_z)

    # "x" was inserted first and never re-accessed — should be evicted
    assert :error = ExCellerate.Cache.get(LimitRegistry, "x")
    assert {:ok, :val_y} = ExCellerate.Cache.get(LimitRegistry, "y")
    assert {:ok, :val_z} = ExCellerate.Cache.get(LimitRegistry, "z")
  end

  test "caching can be disabled per registry" do
    NoCacheRegistry.eval!("1 + 1")
    assert ExCellerate.Cache.get(NoCacheRegistry, "1 + 1") == :error
  end
end

defmodule ExCellerate.CacheStopTest do
  # Separate module because stopping the GenServer destroys the ETS table,
  # which would interfere with LRU eviction tests if they ran in the same
  # randomized test order.
  use ExUnit.Case

  setup do
    case ExCellerate.Cache.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    :ok
  end

  @tag capture_log: true
  test "eval works without cache process running" do
    GenServer.stop(ExCellerate.Cache)

    try do
      assert ExCellerate.eval!("1 + 2") == 3
    after
      case ExCellerate.Cache.start_link() do
        {:ok, _pid} -> :ok
        {:error, {:already_started, _pid}} -> :ok
      end
    end
  end
end
