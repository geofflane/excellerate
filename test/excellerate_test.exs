defmodule ExCellerateTest do
  use ExUnit.Case

  doctest ExCellerate

  alias ExCellerate.Test.DoubleFuncRegistry

  describe "public API" do
    test "eval returns {:ok, result} on success" do
      assert {:ok, 7} = ExCellerate.eval("1 + 2 * 3")
    end

    test "eval returns {:error, _} on parse error" do
      assert {:error, %ExCellerate.Error{type: :parser}} = ExCellerate.eval("1 +")
    end

    test "eval! raises on parse error" do
      assert_raise ExCellerate.Error, fn ->
        ExCellerate.eval!("1 +")
      end
    end

    test "eval! raises on runtime error" do
      assert_raise ExCellerate.Error, fn ->
        ExCellerate.eval!("unknown_var")
      end
    end

    test "validate returns :ok for valid expressions" do
      assert :ok = ExCellerate.validate("1 + 2")
      assert :ok = ExCellerate.validate("abs(-1)")
    end

    test "validate returns error for invalid expressions" do
      assert {:error, %ExCellerate.Error{type: :parser}} = ExCellerate.validate("1 +")
    end

    test "compile returns {:ok, fun} for valid expressions" do
      assert {:ok, fun} = ExCellerate.compile("1 + 2")
      assert is_function(fun, 1)
    end

    test "compile returns {:error, _} for invalid expressions" do
      assert {:error, %ExCellerate.Error{}} = ExCellerate.compile("1 +")
    end

    test "registry eval returns {:ok, result}" do
      assert {:ok, 10} = DoubleFuncRegistry.eval("double(5)")
    end

    test "registry eval! raises on error" do
      assert_raise ExCellerate.Error, fn ->
        DoubleFuncRegistry.eval!("unknown_func(1)")
      end
    end
  end
end
