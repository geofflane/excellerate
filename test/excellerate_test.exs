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

    test "evaluates strings with escapes" do
      assert ExCellerate.eval("'a\\n b'") == "a\n b"
      assert ExCellerate.eval("\"a\\t b\"") == "a\t b"
      assert ExCellerate.eval("'\\'quoted\\''") == "'quoted'"
      assert ExCellerate.eval("\"\\\"quoted\\\"\"") == "\"quoted\""
      assert ExCellerate.eval("'\\\\'") == "\\"
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
      case ExCellerate.eval("unknown", %{}) do
        {:error, %ExCellerate.Error{message: msg}} ->
          assert msg =~ "Function or variable not found: unknown"

        other ->
          flunk("Expected ExCellerate.Error, got #{inspect(other)}")
      end
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

  describe "function calls" do
    test "calls registered functions" do
      # Example: abs(-10) -> 10, round(1.2) -> 1, floor(1.9) -> 1
      assert ExCellerate.eval("abs(-10)") == 10
      assert ExCellerate.eval("round(1.5)") == 2
      assert ExCellerate.eval("max(10, 20)") == 20
      assert ExCellerate.eval("min(10, 20)") == 10
    end

    test "calls ifnull builtin" do
      assert ExCellerate.eval("ifnull(a, 0)", %{"a" => nil}) == 0
      assert ExCellerate.eval("ifnull(a, 0)", %{"a" => 10}) == 10
    end

    test "calls concat builtin" do
      assert ExCellerate.eval("concat('foo', 'bar')") == "foobar"
      assert ExCellerate.eval("concat('a', 1, true)") == "a1true"
    end

    test "calls lookup builtin" do
      assert ExCellerate.eval("lookup(map, 'key')", %{"map" => %{"key" => "val"}}) == "val"
      assert ExCellerate.eval("lookup(list, 1)", %{"list" => ["a", "b", "c"]}) == "b"
      assert ExCellerate.eval("lookup(map, 'missing', 'default')", %{"map" => %{}}) == "default"
      assert ExCellerate.eval("lookup(list, 10, 'oops')", %{"list" => [1]}) == "oops"
    end

    test "calls if builtin" do
      assert ExCellerate.eval("if(true, 1, 0)") == 1
      assert ExCellerate.eval("if(false, 1, 0)") == 0
    end

    test "calls normalize builtin" do
      assert ExCellerate.eval("normalize('Hello World')") == "hello_world"
    end

    test "calls substring builtin" do
      assert ExCellerate.eval("substring('Hello World', 6)") == "World"
      assert ExCellerate.eval("substring('Hello World', 0, 5)") == "Hello"
    end

    test "calls contains builtin" do
      assert ExCellerate.eval("contains('Hello World', 'World')") == true
      assert ExCellerate.eval("contains('Hello World', 'Foo')") == false
    end

    test "calls custom functions from scope" do
      # Custom function passed in the scope/context
      scope = %{
        "custom" => fn x -> x * 2 end
      }

      assert ExCellerate.eval("custom(21)", scope) == 42
    end

    test "allows overriding default functions" do
      # Override 'abs' with a function that always returns 42
      scope = %{
        "abs" => fn _ -> 42 end
      }

      assert ExCellerate.eval("abs(-10)", scope) == 42
    end

    test "supports global registration via Registry" do
      defmodule DoubleFuncRegistry do
        defmodule Double do
          @behaviour ExCellerate.Function
          def name, do: "double"
          def arity, do: 1
          def call([n]), do: n * 2
        end

        use ExCellerate.Registry, plugins: [Double]
      end

      # No 'double' in scope, but it's in the registry
      assert DoubleFuncRegistry.eval("double(5)") == 10
      # Defaults still work
      assert DoubleFuncRegistry.eval("abs(-5)") == 5
    end

    test "registry allows overriding defaults globally" do
      defmodule OverrideRegistry do
        defmodule MyAbs do
          @behaviour ExCellerate.Function
          def name, do: "abs"
          def arity, do: 1
          def call([_]), do: 42
        end

        use ExCellerate.Registry, plugins: [MyAbs]
      end

      assert OverrideRegistry.eval("abs(-10)") == 42
    end
  end

  describe "caching and configuration" do
    setup do
      ExCellerate.Cache.clear()
      :ok
    end

    test "caching respects size limits" do
      defmodule LimitRegistry do
        use ExCellerate.Registry, cache_limit: 2
      end

      LimitRegistry.eval("1")
      LimitRegistry.eval("2")
      LimitRegistry.eval("3")

      # Give the cast time to process
      Process.sleep(20)

      # Match only keys for THIS registry
      count = :ets.select_count(:excellerate_cache, [{{{LimitRegistry, :_}, :_}, [], [true]}])
      assert count <= 2
    end

    test "caching can be disabled per registry" do
      defmodule NoCacheRegistry do
        use ExCellerate.Registry, cache_enabled: false
      end

      NoCacheRegistry.eval("1 + 1")

      assert ExCellerate.Cache.get(NoCacheRegistry, "1 + 1") == :error
    end
  end
end
