defmodule ExCellerate.CompileTest do
  use ExUnit.Case, async: true

  alias ExCellerate.Test.DoubleFuncRegistry

  describe "compile" do
    test "compiled function evaluates with different scopes" do
      {:ok, fun} = ExCellerate.compile("a + b")
      assert fun.(%{"a" => 1, "b" => 2}) == 3
      assert fun.(%{"a" => 10, "b" => 20}) == 30
    end

    test "compiled function works without scope" do
      {:ok, fun} = ExCellerate.compile("1 + 2 * 3")
      assert fun.(%{}) == 7
    end

    test "compile! returns function directly" do
      fun = ExCellerate.compile!("a * 2")
      assert fun.(%{"a" => 5}) == 10
    end

    test "compile! raises on invalid expression" do
      assert_raise ExCellerate.Error, fn ->
        ExCellerate.compile!("1 +")
      end
    end

    test "compiled function with built-in functions" do
      {:ok, fun} = ExCellerate.compile("abs(x) + max(y, z)")
      assert fun.(%{"x" => -5, "y" => 3, "z" => 7}) == 12
    end

    test "compiled function with registry" do
      {:ok, fun} = ExCellerate.compile("double(x)", DoubleFuncRegistry)
      assert fun.(%{"x" => 5}) == 10
      assert fun.(%{"x" => 21}) == 42
    end

    test "compiled function with nested access" do
      {:ok, fun} = ExCellerate.compile("user.profile.name")
      assert fun.(%{"user" => %{"profile" => %{"name" => "Alice"}}}) == "Alice"
      assert fun.(%{"user" => %{"profile" => %{"name" => "Bob"}}}) == "Bob"
    end
  end
end
