defmodule ExCellerate.NativeCompiler.SlotsTest do
  use ExUnit.Case, async: true

  alias ExCellerate.NativeCompiler.Slots

  test "new/1 starts empty" do
    slots = Slots.new(3)
    assert slots.cap == 3
    assert slots.minted == 0
    assert slots.free == []
  end

  test "alloc/1 mints names S0, S1, ... in order" do
    s0 = Slots.new(3)
    assert {:ok, name0, s1} = Slots.alloc(s0)
    assert {:ok, name1, _s2} = Slots.alloc(s1)
    assert name0 == ExCellerate.Compiled.S0
    assert name1 == ExCellerate.Compiled.S1
  end

  test "alloc/1 returns {:full, slots} when free is empty and cap is reached" do
    slots =
      Enum.reduce(1..2, Slots.new(2), fn _, s ->
        {:ok, _name, s} = Slots.alloc(s)
        s
      end)

    assert {:full, ^slots} = Slots.alloc(slots)
  end

  test "alloc/1 reuses a freed name before minting a new one" do
    {:ok, name0, s1} = Slots.alloc(Slots.new(3))
    s_freed = Slots.free(s1, name0)

    # Next alloc reuses the freed name rather than minting S1.
    assert {:ok, ^name0, _} = Slots.alloc(s_freed)
  end

  test "a freed-then-reallocated slot yields the SAME atom (stable reuse)" do
    {:ok, name, s} = Slots.alloc(Slots.new(1))
    # Pool is now full (cap 1). Free it, realloc must return the same atom.
    s = Slots.free(s, name)
    assert {:ok, ^name, _} = Slots.alloc(s)
  end

  test "free/2 lets an at-capacity pool allocate again" do
    {:ok, name, s} = Slots.alloc(Slots.new(1))
    assert {:full, _} = Slots.alloc(s)
    s = Slots.free(s, name)
    assert {:ok, ^name, _} = Slots.alloc(s)
  end

  test "stats/1 reports minted and free counts and reflects alloc/free" do
    assert Slots.stats(Slots.new(3)) == %{minted: 0, free: 0}

    {:ok, name, s} = Slots.alloc(Slots.new(3))
    assert Slots.stats(s) == %{minted: 1, free: 0}

    s = Slots.free(s, name)
    assert Slots.stats(s) == %{minted: 1, free: 1}
  end
end
