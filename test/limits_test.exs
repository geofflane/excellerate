defmodule ExCellerate.LimitsTest do
  # async: false — these tests mutate application env (the configurable limits).
  use ExUnit.Case, async: false

  describe "input length limit" do
    test "rejects expressions longer than the max byte length" do
      huge = String.duplicate("1+", 6_000) <> "1"
      assert byte_size(huge) > 10_000

      assert {:error, %ExCellerate.Error{type: :parser, message: msg}} = ExCellerate.eval(huge)
      assert msg =~ "too long"
    end

    test "accepts expressions at or under the max length" do
      assert {:ok, 3} = ExCellerate.eval("1 + 2")
    end

    test "the max length is configurable via application env" do
      Application.put_env(:excellerate, :max_expression_length, 5)
      on_exit(fn -> Application.delete_env(:excellerate, :max_expression_length) end)

      assert {:error, %ExCellerate.Error{type: :parser}} = ExCellerate.eval("1 + 2 + 3")
    end
  end

  describe "expression depth limit" do
    test "rejects expressions nested deeper than the max depth" do
      # Operator nesting (not bare parens, which collapse in the IR) builds a deep tree.
      deep = "1" <> String.duplicate("+(1", 300) <> String.duplicate(")", 300)
      assert byte_size(deep) < 10_000

      assert {:error, %ExCellerate.Error{type: :compiler, message: msg}} = ExCellerate.eval(deep)
      assert msg =~ "deeply nested"
    end

    test "accepts reasonably nested expressions" do
      expr = "ifs(score > 90, 'A', score > 80, 'B', score > 70, 'C', true, 'F')"
      assert {:ok, "B"} = ExCellerate.eval(expr, %{"score" => 85})
    end

    test "the max depth is configurable via application env" do
      Application.put_env(:excellerate, :max_expression_depth, 3)
      on_exit(fn -> Application.delete_env(:excellerate, :max_expression_depth) end)

      assert {:error, %ExCellerate.Error{type: :compiler}} = ExCellerate.eval("1 + 1 + 1 + 1 + 1")
    end
  end

  describe "factorial limit" do
    test "rejects an operand above the factorial limit" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("999999999!")

      assert msg =~ "too large"
    end

    test "computes large factorials at the default cap without exhausting the stack" do
      # 10_000! is a ~35k-digit bignum; this only completes promptly if the
      # implementation is tail-recursive rather than building a deep call stack.
      result = ExCellerate.eval!("10000!")
      assert is_integer(result) and result > 0
    end

    test "the factorial limit is configurable via application env" do
      Application.put_env(:excellerate, :max_factorial_input, 5)
      on_exit(fn -> Application.delete_env(:excellerate, :max_factorial_input) end)

      assert {:error, %ExCellerate.Error{type: :runtime}} = ExCellerate.eval("6!")
      assert ExCellerate.eval!("5!") == 120
    end
  end
end
