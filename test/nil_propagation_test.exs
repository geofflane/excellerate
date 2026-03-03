defmodule ExCellerate.NilPropagationTest do
  use ExUnit.Case, async: true

  # Nil propagation: accessing a key on nil (or a missing key) returns nil
  # instead of raising. This lets users wrap expressions in ifnull/coalesce
  # rather than writing defensive checks at every level.
  #
  # Root variable lookup still raises — that's a typo, not a data shape issue.

  describe "missing key returns nil" do
    test "missing leaf key on map" do
      scope = %{"user" => %{"name" => "Alice"}}
      assert ExCellerate.eval!("user.missing", scope) == nil
    end

    test "missing intermediate key on map" do
      scope = %{"user" => %{"name" => "Alice"}}
      assert ExCellerate.eval!("user.profile.name", scope) == nil
    end

    test "deeply missing intermediate key" do
      scope = %{"a" => %{}}
      assert ExCellerate.eval!("a.b.c.d", scope) == nil
    end
  end

  describe "nil target returns nil" do
    test "dot access on explicit nil value" do
      scope = %{"user" => nil}
      assert ExCellerate.eval!("user.name", scope) == nil
    end

    test "chained dot access on nil" do
      scope = %{"user" => nil}
      assert ExCellerate.eval!("user.profile.name", scope) == nil
    end

    test "bracket access on nil" do
      scope = %{"list" => nil}
      assert ExCellerate.eval!("list[0]", scope) == nil
    end

    test "mixed dot and bracket on nil" do
      scope = %{"data" => nil}
      assert ExCellerate.eval!("data.items[0].name", scope) == nil
    end
  end

  describe "list index out of bounds returns nil" do
    test "positive index past end" do
      scope = %{"list" => [1, 2, 3]}
      assert ExCellerate.eval!("list[99]", scope) == nil
    end

    test "index on empty list" do
      scope = %{"list" => []}
      assert ExCellerate.eval!("list[0]", scope) == nil
    end

    test "chained access after out-of-bounds index" do
      scope = %{"items" => [%{"name" => "a"}]}
      assert ExCellerate.eval!("items[5].name", scope) == nil
    end
  end

  describe "struct missing field returns nil" do
    test "nonexistent field on struct" do
      scope = %{"uri" => URI.parse("https://example.com")}
      assert ExCellerate.eval!("uri.nonexistent", scope) == nil
    end
  end

  describe "root variable still raises" do
    test "undefined variable returns error" do
      assert {:error, %ExCellerate.Error{message: msg}} =
               ExCellerate.eval("totally_unknown", %{})

      assert msg =~ "variable not found"
    end
  end

  describe "nil propagation composes with functions" do
    test "ifnull provides a default for missing key" do
      scope = %{"user" => %{}}
      assert ExCellerate.eval!("ifnull(user.name, 'anonymous')", scope) == "anonymous"
    end

    test "ifnull provides a default for missing intermediate" do
      scope = %{"user" => %{}}
      assert ExCellerate.eval!("ifnull(user.profile.bio, 'none')", scope) == "none"
    end

    test "coalesce with nil-propagated paths" do
      scope = %{"user" => %{}}
      assert ExCellerate.eval!("coalesce(user.nick, user.name, 'default')", scope) == "default"
    end

    test "isnull detects nil-propagated result" do
      scope = %{"user" => %{}}
      assert ExCellerate.eval!("isnull(user.name)", scope) == true
    end

    test "ternary on nil-propagated result" do
      scope = %{"user" => %{}}
      assert ExCellerate.eval!("user.name ? 'has name' : 'no name'", scope) == "no name"
    end
  end

  describe "spread access is unchanged" do
    test "spread with missing field returns nils" do
      scope = %{"items" => [%{"a" => 1}, %{"b" => 2}]}
      assert ExCellerate.eval!("items[*].a", scope) == [1, nil]
    end

    test "spread with empty list" do
      scope = %{"items" => []}
      assert ExCellerate.eval!("items[*].val", scope) == []
    end

    test "computed spread with missing field returns nils" do
      scope = %{"items" => [%{"x" => 1, "y" => 10}, %{"x" => nil, "y" => 20}]}
      assert ExCellerate.eval!("items[*].(ifnull(x, y))", scope) == [1, 20]
    end
  end

  describe "existing access still works" do
    test "present key returns value" do
      scope = %{"user" => %{"name" => "Alice"}}
      assert ExCellerate.eval!("user.name", scope) == "Alice"
    end

    test "nested present keys" do
      scope = %{"a" => %{"b" => %{"c" => 42}}}
      assert ExCellerate.eval!("a.b.c", scope) == 42
    end

    test "list index in bounds" do
      scope = %{"list" => [10, 20, 30]}
      assert ExCellerate.eval!("list[1]", scope) == 20
    end

    test "mixed access chain" do
      scope = %{"data" => %{"items" => [%{"v" => 99}]}}
      assert ExCellerate.eval!("data.items[0].v", scope) == 99
    end

    test "nil value stored explicitly is returned" do
      scope = %{"x" => nil}
      assert ExCellerate.eval!("x", scope) == nil
    end

    test "struct access still works" do
      scope = %{"uri" => URI.parse("https://example.com")}
      assert ExCellerate.eval!("uri.host", scope) == "example.com"
    end
  end
end
