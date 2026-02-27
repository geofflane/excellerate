defmodule ExCellerateTest do
  use ExUnit.Case
  alias ExCellerate

  describe "simple values" do
    test "evaluates booleans" do
      assert ExCellerate.eval("true") == true
      assert ExCellerate.eval("false") == false
    end

    test "evaluates integers" do
      assert ExCellerate.eval("1") == 1
      assert ExCellerate.eval("123") == 123
      assert ExCellerate.eval("-42") == -42
    end

    test "evaluates floats" do
      assert ExCellerate.eval("1.0") == 1.0
      assert ExCellerate.eval("0.2") == 0.2
      assert ExCellerate.eval(".12") == 0.12
      assert ExCellerate.eval("12.") == 12.0
    end
  end

  describe "variables and data structures" do
    test "accesses variables in scope" do
      assert ExCellerate.eval("a", %{"a" => 10}) == 10
      assert ExCellerate.eval("var_name", %{"var_name" => 42}) == 42
    end

    test "accesses nested map values via dot notation" do
      assert ExCellerate.eval("map.key", %{"map" => %{"key" => 2}}) == 2
      assert ExCellerate.eval("a.b.c", %{"a" => %{"b" => %{"c" => 3}}}) == 3
    end

    test "accesses list values via bracket notation" do
      assert ExCellerate.eval("list[1]", %{"list" => [1, 2, 3]}) == 2
      assert ExCellerate.eval("map.list[0].v", %{"map" => %{"list" => [%{"v" => 2}]}}) == 2
    end

    test "returns error for missing variables" do
      assert ExCellerate.eval("unknown", %{}) == {:error, :not_found}
    end
  end

  describe "advanced operators" do
    test "exponentials" do
      assert ExCellerate.eval("2 ^ 3") == 8
      assert ExCellerate.eval("10 ^ 2") == 100
    end

    test "factorial" do
      assert ExCellerate.eval("5!") == 120
      assert ExCellerate.eval("0!") == 1
    end

    test "bitwise operators" do
      assert ExCellerate.eval("1 << 2") == 4
      assert ExCellerate.eval("8 >> 1") == 4
      assert ExCellerate.eval("3 & 1") == 1
      assert ExCellerate.eval("2 | 1") == 3
      assert ExCellerate.eval("3 |^ 1") == 2
      assert ExCellerate.eval("~1") == -2
    end

    test "boolean operators" do
      assert ExCellerate.eval("true && false") == false
      assert ExCellerate.eval("true || false") == true
      assert ExCellerate.eval("not true") == false
    end

    test "comparison operators" do
      assert ExCellerate.eval("1 == 1") == true
      assert ExCellerate.eval("1 != 2") == true
      assert ExCellerate.eval("5 > 3") == true
      assert ExCellerate.eval("5 >= 5") == true
      assert ExCellerate.eval("2 < 4") == true
      assert ExCellerate.eval("2 <= 2") == true
    end

    test "ternary operator" do
      assert ExCellerate.eval("true ? 1 : 0") == 1
      assert ExCellerate.eval("false ? 1 : 0") == 0
      assert ExCellerate.eval("1 == 1 ? a : b", %{"a" => 10, "b" => 20}) == 10
    end
  end
end
