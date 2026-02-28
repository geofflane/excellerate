defmodule ExCellerate.OperatorsTest do
  use ExUnit.Case, async: true

  describe "basic arithmetic" do
    test "subtraction" do
      assert ExCellerate.eval!("5 - 3") == 2
      assert ExCellerate.eval!("3 - 5") == -2
    end

    test "multiplication" do
      assert ExCellerate.eval!("3 * 4") == 12
      assert ExCellerate.eval!("0 * 100") == 0
    end

    test "division" do
      assert ExCellerate.eval!("10 / 2") == 5.0
      assert ExCellerate.eval!("7 / 2") == 3.5
    end

    test "division by zero returns error" do
      assert {:error, _} = ExCellerate.eval("1 / 0")
    end

    test "double negation" do
      assert ExCellerate.eval!("- -5") == 5
    end

    test "subtraction of negative" do
      assert ExCellerate.eval!("3 - -2") == 5
    end

    test "zero" do
      assert ExCellerate.eval!("0") == 0
    end
  end

  describe "advanced operators" do
    test "exponentials" do
      assert ExCellerate.eval!("2 ^ 3") == 8
      assert ExCellerate.eval!("10 ^ 2") == 100
      assert ExCellerate.eval!("2 ^ -1") == 0.5
    end

    test "factorial" do
      assert ExCellerate.eval!("5!") == 120
      assert ExCellerate.eval!("0!") == 1
    end

    test "bitwise operators" do
      assert ExCellerate.eval!("1 << 2") == 4
      assert ExCellerate.eval!("8 >> 1") == 4
      assert ExCellerate.eval!("3 & 1") == 1
      assert ExCellerate.eval!("2 | 1") == 3
      assert ExCellerate.eval!("3 |^ 1") == 2
      assert ExCellerate.eval!("~1") == -2
    end

    test "boolean operators" do
      assert ExCellerate.eval!("true && false") == false
      assert ExCellerate.eval!("true || false") == true
      assert ExCellerate.eval!("not true") == false
    end

    test "comparison operators" do
      assert ExCellerate.eval!("1 == 1") == true
      assert ExCellerate.eval!("1 != 2") == true
      assert ExCellerate.eval!("5 > 3") == true
      assert ExCellerate.eval!("5 >= 5") == true
      assert ExCellerate.eval!("2 < 4") == true
      assert ExCellerate.eval!("2 <= 2") == true
    end

    test "ternary operator" do
      assert ExCellerate.eval!("true ? 1 : 0") == 1
      assert ExCellerate.eval!("false ? 1 : 0") == 0
      assert ExCellerate.eval!("1 == 1 ? a : b", %{"a" => 10, "b" => 20}) == 10
    end
  end

  describe "modulo operator" do
    test "basic modulo" do
      assert ExCellerate.eval!("10 % 3") == 1
      assert ExCellerate.eval!("7 % 2") == 1
      assert ExCellerate.eval!("8 % 4") == 0
    end

    test "modulo has same precedence as multiplication" do
      # 10 + 7 % 3 should be 10 + 1 = 11 (% binds tighter than +)
      assert ExCellerate.eval!("10 + 7 % 3") == 11
    end

    test "negative modulo" do
      assert ExCellerate.eval!("-7 % 3") == -1
    end
  end

  describe "operator precedence" do
    test "multiplication binds tighter than addition" do
      assert ExCellerate.eval!("1 + 2 * 3") == 7
      assert ExCellerate.eval!("2 * 3 + 4 * 5") == 26
    end

    test "exponent binds tighter than multiplication" do
      assert ExCellerate.eval!("2 ^ 3 * 2") == 16.0
    end

    test "parentheses override precedence" do
      assert ExCellerate.eval!("(1 + 2) * 3") == 9
      assert ExCellerate.eval!("2 * (3 + 4)") == 14
      assert ExCellerate.eval!("(2 + 3) ^ 2") == 25.0
    end

    test "nested parentheses" do
      assert ExCellerate.eval!("((1 + 2) * (3 + 4))") == 21
      assert ExCellerate.eval!("((1))") == 1
    end

    test "logical AND binds tighter than OR" do
      assert ExCellerate.eval!("true || false && false") == true
      assert ExCellerate.eval!("false || true && true") == true
    end

    test "comparison binds tighter than logical" do
      assert ExCellerate.eval!("1 < 2 && 3 > 1") == true
      assert ExCellerate.eval!("1 > 2 || 3 > 1") == true
    end

    test "unary minus binds tighter than binary operators" do
      assert ExCellerate.eval!("-2 + 3") == 1
      assert ExCellerate.eval!("3 + -2") == 1
    end

    test "exponent is left-associative" do
      # Left-assoc: 2^3^2 = (2^3)^2 = 8^2 = 64
      assert ExCellerate.eval!("2 ^ 3 ^ 2") == 64.0
    end
  end

  describe "nested expressions" do
    test "nested function calls" do
      assert ExCellerate.eval!("abs(min(-5, -10))") == 10
      assert ExCellerate.eval!("max(abs(-3), abs(-7))") == 7
    end

    test "function call as operator argument" do
      assert ExCellerate.eval!("abs(-3) + abs(-4)") == 7
    end

    test "nested ternary in true branch" do
      assert ExCellerate.eval!("true ? (false ? 1 : 2) : 3") == 2
    end

    test "nested ternary in false branch" do
      assert ExCellerate.eval!("false ? 1 : (true ? 2 : 3)") == 2
    end

    test "bracket access with expression index" do
      assert ExCellerate.eval!("list[1 + 1]", %{"list" => [10, 20, 30]}) == 30
    end

    test "bracket access with variable index" do
      assert ExCellerate.eval!("list[idx]", %{"list" => [10, 20, 30], "idx" => 2}) == 30
    end
  end

  # ── Bug regression tests ──────────────────────────────────────────

  describe "factorial edge cases" do
    test "negative factorial returns error" do
      assert {:error, %ExCellerate.Error{type: :runtime}} =
               ExCellerate.eval("(-1)!")
    end

    test "float factorial returns error" do
      assert {:error, %ExCellerate.Error{type: :runtime}} =
               ExCellerate.eval("(1.5)!")
    end
  end
end
