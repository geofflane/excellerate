defmodule ExCellerate.CacheTest do
  use ExUnit.Case

  alias ExCellerate.Test.LimitRegistry
  alias ExCellerate.Test.NoCacheRegistry

  describe "caching and configuration" do
    setup do
      # Ensure cache process is running for caching tests
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

      # Match only keys for THIS registry
      count =
        :ets.select_count(:excellerate_cache, [
          {{{LimitRegistry, :_}, :_, :_}, [], [true]}
        ])

      assert count <= 2
    end

    test "LRU eviction removes least recently used entry" do
      # LimitRegistry has cache_limit: 2
      # Insert two entries
      LimitRegistry.eval!("10 + 1")
      LimitRegistry.eval!("10 + 2")

      # Access the first one again to make it most-recently-used
      LimitRegistry.eval!("10 + 1")

      # Insert a third — should evict "10 + 2" (least recently used), not "10 + 1"
      LimitRegistry.eval!("10 + 3")

      # "10 + 1" should still be cached (it was accessed more recently)
      assert ExCellerate.Cache.get(LimitRegistry, "10 + 1") != :error

      # "10 + 2" should have been evicted (least recently used)
      assert ExCellerate.Cache.get(LimitRegistry, "10 + 2") == :error
    end

    test "LRU eviction keeps most recently inserted when no re-access" do
      # Insert three entries with limit 2
      LimitRegistry.eval!("20 + 1")
      LimitRegistry.eval!("20 + 2")
      LimitRegistry.eval!("20 + 3")

      # The first entry should be evicted
      assert ExCellerate.Cache.get(LimitRegistry, "20 + 1") == :error

      # The two most recent should remain
      assert ExCellerate.Cache.get(LimitRegistry, "20 + 2") != :error
      assert ExCellerate.Cache.get(LimitRegistry, "20 + 3") != :error
    end

    test "caching can be disabled per registry" do
      NoCacheRegistry.eval!("1 + 1")

      assert ExCellerate.Cache.get(NoCacheRegistry, "1 + 1") == :error
    end

    @tag capture_log: true
    test "eval works without cache process running" do
      # Without the cache started, eval still works — just no caching
      GenServer.stop(ExCellerate.Cache)

      on_exit(fn ->
        case ExCellerate.Cache.start_link() do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
        end
      end)

      assert ExCellerate.eval!("1 + 2") == 3
    end
  end
end
