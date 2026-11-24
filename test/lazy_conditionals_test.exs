defmodule ExCellerate.LazyConditionalsTest do
  # The built-in conditional functions evaluate only the arguments they need,
  # like `&&`, `||` and the ternary operator, while returning exactly what their
  # eager `call/1` would.
  use ExUnit.Case, async: true

  alias ExCellerate.Functions.General.{And, Coalesce, If, IfNull, Ifs, Or, Switch}
  alias ExCellerate.Test.CustomIfRegistry

  # `boom` raises if evaluated.
  @boom "1 / 0"

  describe "unselected arguments are not evaluated" do
    test "if" do
      assert ExCellerate.eval!("if(true, 1, #{@boom})") == 1
      assert ExCellerate.eval!("if(false, #{@boom}, 2)") == 2
      assert ExCellerate.eval!("if(false, #{@boom})") == nil
      assert ExCellerate.eval!("if(x != 0, 10 / x, 0)", %{"x" => 0}) == 0
    end

    test "ifs" do
      assert ExCellerate.eval!("ifs(true, 1, #{@boom}, #{@boom})") == 1
      assert ExCellerate.eval!("ifs(false, #{@boom}, true, 2, #{@boom}, 3)") == 2
    end

    test "and / or" do
      assert ExCellerate.eval!("and(false, #{@boom})") == false
      assert ExCellerate.eval!("or(true, #{@boom})") == true
      assert ExCellerate.eval!("and(x != 0, 10 / x > 1)", %{"x" => 0}) == false
    end

    test "coalesce / ifnull" do
      assert ExCellerate.eval!("coalesce(null, 'a', #{@boom})") == "a"
      assert ExCellerate.eval!("ifnull('a', #{@boom})") == "a"
    end

    test "switch" do
      assert ExCellerate.eval!("switch('b', 'a', #{@boom}, 'b', 2, #{@boom}, 3)") == 2
      assert ExCellerate.eval!("switch('z', 'a', #{@boom}, 'default')") == "default"
    end

    test "the subject of switch is evaluated once" do
      # Evaluating `x` once vs. per comparison is observable only through
      # errors/side effects; a raising subject must raise exactly as before.
      assert {:error, _} = ExCellerate.eval("switch(#{@boom}, 1, 'one')")
    end

    test "selected arguments that raise still raise" do
      assert {:error, _} = ExCellerate.eval("if(true, #{@boom}, 1)")
      assert {:error, _} = ExCellerate.eval("and(true, #{@boom})")
      assert {:error, _} = ExCellerate.eval("coalesce(null, #{@boom})")
    end
  end

  describe "results match the eager call/1 for every input" do
    @values [true, false, nil, 0, 1, "", "x", []]

    test "if/2 and if/3" do
      for c <- @values, t <- [1, nil], e <- [2, nil] do
        scope = %{"c" => c, "t" => t, "e" => e}
        assert ExCellerate.eval!("if(c, t)", scope) == If.call([c, t])
        assert ExCellerate.eval!("if(c, t, e)", scope) == If.call([c, t, e])
      end
    end

    test "and / or" do
      for a <- @values, b <- @values do
        scope = %{"a" => a, "b" => b}
        assert ExCellerate.eval!("and(a, b)", scope) === And.call([a, b])
        assert ExCellerate.eval!("or(a, b)", scope) === Or.call([a, b])
        assert ExCellerate.eval!("and(a)", scope) === And.call([a])
        assert ExCellerate.eval!("or(a, b, a)", scope) === Or.call([a, b, a])
      end

      assert ExCellerate.eval!("and()") === And.call([])
      assert ExCellerate.eval!("or()") === Or.call([])
    end

    test "coalesce / ifnull" do
      for a <- @values, b <- @values do
        scope = %{"a" => a, "b" => b}
        assert ExCellerate.eval!("coalesce(a, b)", scope) === Coalesce.call([a, b])
        assert ExCellerate.eval!("ifnull(a, b)", scope) === IfNull.call([a, b])
      end

      assert ExCellerate.eval!("coalesce()") === Coalesce.call([])
    end

    test "ifs" do
      for c1 <- @values, c2 <- @values do
        scope = %{"c1" => c1, "c2" => c2}
        assert ExCellerate.eval!("ifs(c1, 1, c2, 2)", scope) === Ifs.call([c1, 1, c2, 2])
      end
    end

    test "switch" do
      for s <- [1, 1.0, "a", nil, false], c <- [1, "a", nil] do
        scope = %{"s" => s, "c" => c}
        assert ExCellerate.eval!("switch(s, c, 'hit')", scope) === Switch.call([s, c, "hit"])

        assert ExCellerate.eval!("switch(s, c, 'hit', 'other')", scope) ===
                 Switch.call([s, c, "hit", "other"])
      end

      assert ExCellerate.eval!("switch(1)") === Switch.call([1])
    end
  end

  describe "argument shapes that are errors keep their existing errors" do
    test "ifs with an odd or empty argument list" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("ifs(true, 1, false)")

      assert msg =~ "requires an even number of arguments"
      assert {:error, %ExCellerate.Error{type: :runtime}} = ExCellerate.eval("ifs()")
    end

    test "switch with no arguments" do
      assert {:error, %ExCellerate.Error{type: :runtime}} = ExCellerate.eval("switch()")
    end

    test "arity is still checked at compile time" do
      assert {:error, %ExCellerate.Error{type: :compiler}} = ExCellerate.eval("if(true)")
      assert {:error, %ExCellerate.Error{type: :compiler}} = ExCellerate.eval("ifnull(1)")
    end
  end

  test "a registry's own function with a built-in's name stays an ordinary call" do
    assert CustomIfRegistry.eval!("if(true, 1, 2)") == [:custom_if, true, 1, 2]
    assert {:error, _} = CustomIfRegistry.eval("if(true, 1, #{@boom})")
  end
end
