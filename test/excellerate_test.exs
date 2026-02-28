defmodule ExCellerateTest do
  use ExUnit.Case

  doctest ExCellerate

  alias ExCellerate
  alias ExCellerate.Test.DoubleFuncRegistry
  alias ExCellerate.Test.LimitRegistry
  alias ExCellerate.Test.NoCacheRegistry
  alias ExCellerate.Test.OverrideRegistry

  describe "simple values" do
    test "evaluates booleans" do
      assert ExCellerate.eval!("true") == true
      assert ExCellerate.eval!("false") == false
    end

    test "evaluates null" do
      assert ExCellerate.eval!("null") == nil
    end

    test "evaluates integers" do
      assert ExCellerate.eval!("1") == 1
      assert ExCellerate.eval!("123") == 123
      assert ExCellerate.eval!("-42") == -42
    end

    test "evaluates floats" do
      assert ExCellerate.eval!("1.0") == 1.0
      assert ExCellerate.eval!("0.2") == 0.2
      assert ExCellerate.eval!(".12") == 0.12
      assert ExCellerate.eval!("12.") == 12.0
    end

    test "evaluates strings with escapes" do
      assert ExCellerate.eval!("'a\\n b'") == "a\n b"
      assert ExCellerate.eval!("\"a\\t b\"") == "a\t b"
      assert ExCellerate.eval!("'\\'quoted\\''") == "'quoted'"
      assert ExCellerate.eval!("\"\\\"quoted\\\"\"") == "\"quoted\""
      assert ExCellerate.eval!("'\\\\'") == "\\"
    end
  end

  describe "variables and data structures" do
    test "accesses variables in scope" do
      assert ExCellerate.eval!("a", %{"a" => 10}) == 10
      assert ExCellerate.eval!("var_name", %{"var_name" => 42}) == 42
      assert ExCellerate.eval!("atom_key", %{atom_key: 7}) == 7
    end

    test "accesses nested map values via dot notation" do
      assert ExCellerate.eval!("map.key", %{"map" => %{"key" => 2}}) == 2
      assert ExCellerate.eval!("a.b.c", %{"a" => %{"b" => %{"c" => 3}}}) == 3
    end

    test "accesses list values via bracket notation" do
      assert ExCellerate.eval!("list[1]", %{"list" => [1, 2, 3]}) == 2
      assert ExCellerate.eval!("map.list[0].v", %{"map" => %{"list" => [%{"v" => 2}]}}) == 2
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

  describe "function calls" do
    test "calls registered functions" do
      assert ExCellerate.eval!("abs(-10)") == 10
      assert ExCellerate.eval!("round(1.5)") == 2
      assert ExCellerate.eval!("max(10, 20)") == 20
      assert ExCellerate.eval!("min(10, 20)") == 10
      assert ExCellerate.eval!("ceil(1.2)") == 2
      assert ExCellerate.eval!("floor(1.9)") == 1
    end

    test "calls ifnull builtin" do
      assert ExCellerate.eval!("ifnull(a, 0)", %{"a" => nil}) == 0
      assert ExCellerate.eval!("ifnull(a, 0)", %{"a" => 10}) == 10
    end

    test "calls concat builtin" do
      assert ExCellerate.eval!("concat('foo', 'bar')") == "foobar"
      assert ExCellerate.eval!("concat('a', 1, true)") == "a1true"
    end

    test "calls lookup builtin" do
      assert ExCellerate.eval!("lookup(map, 'key')", %{"map" => %{"key" => "val"}}) == "val"
      assert ExCellerate.eval!("lookup(list, 1)", %{"list" => ["a", "b", "c"]}) == "b"
      assert ExCellerate.eval!("lookup(map, 'missing', 'default')", %{"map" => %{}}) == "default"
      assert ExCellerate.eval!("lookup(list, 10, 'oops')", %{"list" => [1]}) == "oops"
    end

    test "lookup with list and default" do
      assert ExCellerate.eval!("lookup(list, 10, 'oob')", %{"list" => ["a"]}) == "oob"
    end

    test "lookup with non-map/list and default returns default" do
      assert ExCellerate.eval!("lookup(val, 'k', 'fallback')", %{"val" => 42}) == "fallback"
    end

    test "lookup with non-map/list and no default returns nil" do
      assert ExCellerate.eval!("lookup(val, 'k')", %{"val" => 42}) == nil
    end

    test "calls if builtin" do
      assert ExCellerate.eval!("if(true, 1, 0)") == 1
      assert ExCellerate.eval!("if(false, 1, 0)") == 0
    end

    test "calls normalize builtin" do
      assert ExCellerate.eval!("normalize('Hello World')") == "hello_world"
    end

    test "normalize with non-string returns value unchanged" do
      assert ExCellerate.eval!("normalize(42)", %{}) == 42
      assert ExCellerate.eval!("normalize(null)", %{}) == nil
    end

    test "calls substring builtin" do
      assert ExCellerate.eval!("substring('Hello World', 6)") == "World"
      assert ExCellerate.eval!("substring('Hello World', 0, 5)") == "Hello"
    end

    test "substring with non-string returns nil" do
      assert ExCellerate.eval!("substring(123, 0)", %{}) == nil
    end

    test "calls contains builtin" do
      assert ExCellerate.eval!("contains('Hello World', 'World')") == true
      assert ExCellerate.eval!("contains('Hello World', 'Foo')") == false
    end

    test "contains returns false for non-string args" do
      assert ExCellerate.eval!("contains(123, 'foo')", %{}) == false
      assert ExCellerate.eval!("contains(null, 'foo')", %{}) == false
    end

    test "calls len builtin" do
      assert ExCellerate.eval!("len('hello')") == 5
      assert ExCellerate.eval!("len('')") == 0
      assert ExCellerate.eval!("len(name)", %{"name" => "Alice"}) == 5
    end

    test "calls left builtin" do
      assert ExCellerate.eval!("left('Hello World', 5)") == "Hello"
      assert ExCellerate.eval!("left('Hi', 10)") == "Hi"
      assert ExCellerate.eval!("left('Hello', 0)") == ""
    end

    test "calls right builtin" do
      assert ExCellerate.eval!("right('Hello World', 5)") == "World"
      assert ExCellerate.eval!("right('Hi', 10)") == "Hi"
      assert ExCellerate.eval!("right('Hello', 0)") == ""
    end

    test "calls upper builtin" do
      assert ExCellerate.eval!("upper('hello')") == "HELLO"
      assert ExCellerate.eval!("upper('Hello World')") == "HELLO WORLD"
      assert ExCellerate.eval!("upper('ABC')") == "ABC"
    end

    test "calls lower builtin" do
      assert ExCellerate.eval!("lower('HELLO')") == "hello"
      assert ExCellerate.eval!("lower('Hello World')") == "hello world"
      assert ExCellerate.eval!("lower('abc')") == "abc"
    end

    test "calls trim builtin" do
      assert ExCellerate.eval!("trim('  hello  ')") == "hello"
      assert ExCellerate.eval!("trim('hello')") == "hello"
      assert ExCellerate.eval!("trim('\\thello\\n')") == "hello"
    end

    test "calls replace builtin" do
      assert ExCellerate.eval!("replace('hello world', 'world', 'there')") == "hello there"
      assert ExCellerate.eval!("replace('aaa', 'a', 'b')") == "bbb"
      assert ExCellerate.eval!("replace('hello', 'xyz', 'abc')") == "hello"
    end

    test "calls find builtin" do
      assert ExCellerate.eval!("find('world', 'hello world')") == 6
      assert ExCellerate.eval!("find('xyz', 'hello')") == -1
      assert ExCellerate.eval!("find('hel', 'hello')") == 0
    end

    test "calls sqrt builtin" do
      assert ExCellerate.eval!("sqrt(9)") == 3.0
      assert ExCellerate.eval!("sqrt(2)") == :math.sqrt(2)
      assert ExCellerate.eval!("sqrt(0)") == 0.0
    end

    test "sqrt of negative returns error" do
      assert {:error, _} = ExCellerate.eval("sqrt(-1)")
    end

    test "calls log builtin" do
      assert ExCellerate.eval!("log(8, 2)") == :math.log(8) / :math.log(2)
      assert ExCellerate.eval!("log(100, 10)") == :math.log(100) / :math.log(10)
    end

    test "calls ln builtin" do
      assert ExCellerate.eval!("ln(1)") == 0.0
      assert_in_delta ExCellerate.eval!("ln(2.718281828)"), 1.0, 0.0001
    end

    test "calls log10 builtin" do
      assert ExCellerate.eval!("log10(100)") == 2.0
      assert ExCellerate.eval!("log10(1000)") == :math.log10(1000)
    end

    test "calls exp builtin" do
      assert ExCellerate.eval!("exp(0)") == 1.0
      assert ExCellerate.eval!("exp(1)") == :math.exp(1)
    end

    test "calls sign builtin" do
      assert ExCellerate.eval!("sign(-42)") == -1
      assert ExCellerate.eval!("sign(0)") == 0
      assert ExCellerate.eval!("sign(42)") == 1
      assert ExCellerate.eval!("sign(-0.5)") == -1
      assert ExCellerate.eval!("sign(0.001)") == 1
    end

    test "calls trunc builtin" do
      assert ExCellerate.eval!("trunc(3.7)") == 3
      assert ExCellerate.eval!("trunc(-3.7)") == -3
      assert ExCellerate.eval!("trunc(5)") == 5
    end

    test "calls sum builtin" do
      assert ExCellerate.eval!("sum(1, 2, 3)") == 6
      assert ExCellerate.eval!("sum(10)") == 10
      assert ExCellerate.eval!("sum(1, 2, 3, 4, 5)") == 15
      assert ExCellerate.eval!("sum(a, b, c)", %{"a" => 10, "b" => 20, "c" => 30}) == 60
    end

    test "calls avg builtin" do
      assert ExCellerate.eval!("avg(2, 4, 6)") == 4.0
      assert ExCellerate.eval!("avg(10)") == 10.0
      assert ExCellerate.eval!("avg(1, 2)") == 1.5
    end

    test "calls coalesce builtin" do
      assert ExCellerate.eval!("coalesce(null, null, 'found')", %{}) == "found"
      assert ExCellerate.eval!("coalesce('first', 'second')") == "first"
      assert ExCellerate.eval!("coalesce(null, null)", %{}) == nil
      assert ExCellerate.eval!("coalesce(a, b, c)", %{"a" => nil, "b" => nil, "c" => 42}) == 42
    end

    test "calls switch builtin" do
      assert ExCellerate.eval!("switch('B', 'A', 1, 'B', 2, 'C', 3)") == 2
      assert ExCellerate.eval!("switch('D', 'A', 1, 'B', 2, 'unknown')") == "unknown"
      assert ExCellerate.eval!("switch('D', 'A', 1, 'B', 2)") == nil
    end

    test "switch with scope variables" do
      scope = %{"status" => "active"}

      assert ExCellerate.eval!(
               "switch(status, 'active', 'Running', 'paused', 'Paused', 'Unknown')",
               scope
             ) == "Running"
    end

    test "calls and builtin" do
      assert ExCellerate.eval!("and(true, true, true)") == true
      assert ExCellerate.eval!("and(true, false, true)") == false
      assert ExCellerate.eval!("and(true)") == true
      assert ExCellerate.eval!("and(false)") == false
    end

    test "calls or builtin" do
      assert ExCellerate.eval!("or(false, false, true)") == true
      assert ExCellerate.eval!("or(false, false, false)") == false
      assert ExCellerate.eval!("or(true)") == true
      assert ExCellerate.eval!("or(false)") == false
    end

    test "calls textjoin builtin" do
      assert ExCellerate.eval!("textjoin(', ', 'a', 'b', 'c')") == "a, b, c"
      assert ExCellerate.eval!("textjoin('-', 1, 2, 3)") == "1-2-3"
      assert ExCellerate.eval!("textjoin(', ', 'only')") == "only"
    end

    test "textjoin with scope variables" do
      scope = %{"a" => "hello", "b" => "world"}
      assert ExCellerate.eval!("textjoin(' ', a, b)", scope) == "hello world"
    end

    test "calls custom functions from scope" do
      # Custom function passed in the scope/context
      scope = %{
        "custom" => fn x -> x * 2 end
      }

      assert ExCellerate.eval!("custom(21)", scope) == 42
    end

    test "allows overriding default functions" do
      # Override 'abs' with a function that always returns 42
      scope = %{
        "abs" => fn _ -> 42 end
      }

      assert ExCellerate.eval!("abs(-10)", scope) == 42
    end

    test "supports global registration via Registry" do
      # No 'double' in scope, but it's in the registry
      assert DoubleFuncRegistry.eval!("double(5)") == 10
      # Defaults still work
      assert DoubleFuncRegistry.eval!("abs(-5)") == 5
    end

    test "registry allows overriding defaults globally" do
      assert OverrideRegistry.eval!("abs(-10)") == 42
    end
  end

  describe "arity validation" do
    test "rejects too many args for fixed-arity function" do
      assert {:error, %ExCellerate.Error{type: :compiler, message: msg}} =
               ExCellerate.eval("abs(1, 2)")

      assert msg =~ "abs"
      assert msg =~ "1"
      assert msg =~ "2"
    end

    test "rejects too few args for fixed-arity function" do
      assert {:error, %ExCellerate.Error{type: :compiler, message: msg}} =
               ExCellerate.eval("left('hello')")

      assert msg =~ "left"
      assert msg =~ "2"
      assert msg =~ "1"
    end

    test "allows variadic functions with any number of args" do
      assert ExCellerate.eval!("concat('a')") == "a"
      assert ExCellerate.eval!("concat('a', 'b', 'c')") == "abc"
    end

    test "validates arity through a registry" do
      assert {:error, %ExCellerate.Error{type: :compiler, message: msg}} =
               DoubleFuncRegistry.eval("double(1, 2)")

      assert msg =~ "double"
    end

    test "validates arity for scope functions at runtime" do
      scope = %{"add" => fn a, b -> a + b end}

      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("add(1, 2, 3)", scope)

      assert msg =~ "arity"
    end

    test "scope functions with correct arity succeed" do
      scope = %{"add" => fn a, b -> a + b end}
      assert ExCellerate.eval!("add(1, 2)", scope) == 3
    end

    test "validate/2 catches arity errors without executing" do
      assert {:error, %ExCellerate.Error{type: :compiler}} =
               ExCellerate.validate("abs(1, 2)")
    end
  end

  # ── Spread notation [*] ──────────────────────────────────────────

  describe "spread notation" do
    setup do
      scope = %{
        "orders" => [
          %{"product" => "Widget", "price" => 10, "qty" => 2},
          %{"product" => "Gadget", "price" => 25, "qty" => 1},
          %{"product" => "Thing", "price" => 5, "qty" => 10}
        ]
      }

      {:ok, scope: scope}
    end

    test "extracts a column from a list of maps", %{scope: scope} do
      assert ExCellerate.eval!("orders[*].price", scope) == [10, 25, 5]
      assert ExCellerate.eval!("orders[*].product", scope) == ["Widget", "Gadget", "Thing"]
    end

    test "sum over a column", %{scope: scope} do
      assert ExCellerate.eval!("sum(orders[*].price)", scope) == 40
    end

    test "avg over a column", %{scope: scope} do
      assert_in_delta ExCellerate.eval!("avg(orders[*].qty)", scope), 4.333, 0.01
    end

    test "max over a column", %{scope: scope} do
      assert ExCellerate.eval!("max(orders[*].price)", scope) == 25
    end

    test "min over a column", %{scope: scope} do
      assert ExCellerate.eval!("min(orders[*].price)", scope) == 5
    end

    test "len counts items in spread result", %{scope: scope} do
      assert ExCellerate.eval!("len(orders[*].product)", scope) == 3
    end

    test "textjoin over a column", %{scope: scope} do
      assert ExCellerate.eval!("textjoin(', ', orders[*].product)", scope) ==
               "Widget, Gadget, Thing"
    end

    test "deep nested access after spread" do
      scope = %{
        "users" => [
          %{"profile" => %{"name" => "Alice"}},
          %{"profile" => %{"name" => "Bob"}}
        ]
      }

      assert ExCellerate.eval!("users[*].profile.name", scope) == ["Alice", "Bob"]
    end

    test "nested spread flattens results" do
      scope = %{
        "departments" => [
          %{"employees" => [%{"name" => "Alice"}, %{"name" => "Bob"}]},
          %{"employees" => [%{"name" => "Carol"}]}
        ]
      }

      assert ExCellerate.eval!("departments[*].employees[*].name", scope) ==
               ["Alice", "Bob", "Carol"]
    end

    test "spread with compiled function", %{scope: scope} do
      {:ok, fun} = ExCellerate.compile("sum(orders[*].price)")
      assert fun.(scope) == 40

      other_scope = %{
        "orders" => [
          %{"price" => 100},
          %{"price" => 200}
        ]
      }

      assert fun.(other_scope) == 300
    end

    test "spread on simple list of values" do
      scope = %{"numbers" => [1, 2, 3, 4, 5]}
      assert ExCellerate.eval!("sum(numbers)", scope) == 15
    end

    test "spread with atom-keyed maps" do
      scope = %{"items" => [%{name: "a", value: 1}, %{name: "b", value: 2}]}
      assert ExCellerate.eval!("items[*].value", scope) == [1, 2]
      assert ExCellerate.eval!("sum(items[*].value)", scope) == 3
    end

    test "spread with mixed nesting depths" do
      scope = %{
        "data" => %{
          "rows" => [
            %{"scores" => [10, 20, 30]},
            %{"scores" => [40, 50]}
          ]
        }
      }

      # First get the scores arrays
      assert ExCellerate.eval!("data.rows[*].scores", scope) == [[10, 20, 30], [40, 50]]
    end

    test "nested spread flattens across multiple levels" do
      scope = %{
        "data" => %{
          "rows" => [
            %{"scores" => [10, 20, 30]},
            %{"scores" => [40, 50]}
          ]
        }
      }

      # Nested spread should flatten the inner lists
      assert ExCellerate.eval!("sum(data.rows[*].scores[*])", scope) == 150
    end

    test "spread through list of lists" do
      scope = %{"matrix" => [[1, 2], [3, 4], [5, 6]]}
      assert ExCellerate.eval!("sum(matrix[*][*])", scope) == 21
    end

    test "spread with struct values" do
      scope = %{
        "endpoints" => [
          URI.parse("https://api.example.com"),
          URI.parse("https://cdn.example.com")
        ]
      }

      assert ExCellerate.eval!("endpoints[*].host", scope) ==
               ["api.example.com", "cdn.example.com"]
    end

    test "spread result used in contains" do
      scope = %{
        "tags" => [
          %{"label" => "urgent"},
          %{"label" => "review"},
          %{"label" => "bug"}
        ]
      }

      assert ExCellerate.eval!("contains(textjoin(',', tags[*].label), 'urgent')", scope) == true
    end

    test "spread with single-element list" do
      scope = %{"items" => [%{"val" => 42}]}
      assert ExCellerate.eval!("items[*].val", scope) == [42]
      assert ExCellerate.eval!("sum(items[*].val)", scope) == 42
    end

    test "spread with empty list" do
      scope = %{"items" => []}
      assert ExCellerate.eval!("items[*].val", scope) == []
    end

    test "specific index after spread" do
      scope = %{
        "data" => %{
          "rows" => [
            %{"scores" => [10, 20, 30]},
            %{"scores" => [40, 50, 60]}
          ]
        }
      }

      # Get the second score from each row
      assert ExCellerate.eval!("data.rows[*].scores[1]", scope) == [20, 50]
      assert ExCellerate.eval!("sum(data.rows[*].scores[0])", scope) == 50
    end

    test "dot access after spread then bracket index" do
      scope = %{
        "teams" => [
          %{"members" => [%{"name" => "Alice"}, %{"name" => "Bob"}]},
          %{"members" => [%{"name" => "Carol"}, %{"name" => "Dave"}]}
        ]
      }

      # Get the first member's name from each team
      assert ExCellerate.eval!("teams[*].members[0].name", scope) == ["Alice", "Carol"]
    end
  end

  # ── Complex integration expressions ──────────────────────────────

  describe "complex expressions combining multiple features" do
    test "arithmetic with multiple scope variables" do
      scope = %{"price" => 25.0, "quantity" => 4, "tax_rate" => 0.08}
      assert ExCellerate.eval!("price * quantity * (1 + tax_rate)", scope) == 108.0
    end

    test "nested access with arithmetic and functions" do
      scope = %{
        "order" => %{
          "items" => [
            %{"price" => 10.5, "qty" => 2},
            %{"price" => 7.25, "qty" => 3}
          ],
          "discount" => 5
        }
      }

      # Compute total for first item minus discount
      assert ExCellerate.eval!(
               "order.items[0].price * order.items[0].qty - order.discount",
               scope
             ) == 16.0
    end

    test "ternary with comparison on computed values" do
      scope = %{"score" => 85, "threshold" => 70, "bonus" => 10}

      assert ExCellerate.eval!(
               "score + bonus >= 90 ? 'A' : 'B'",
               scope
             ) == "A"
    end

    test "chained function calls with scope variables" do
      scope = %{"x" => -15, "y" => 7, "z" => 3}
      # abs(-15) + max(7, 3) + min(7, 3) = 15 + 7 + 3 = 25
      assert ExCellerate.eval!("abs(x) + max(y, z) + min(y, z)", scope) == 25
    end

    test "string functions with scope and concatenation" do
      scope = %{"first" => "Jane", "last" => "Doe", "greeting" => "Hello"}

      assert ExCellerate.eval!(
               "concat(greeting, ' ', first, ' ', last)",
               scope
             ) == "Hello Jane Doe"
    end

    test "nested ternary with function calls and comparisons" do
      scope = %{"val" => -42}

      # If abs(val) > 100 then "big", else if abs(val) > 10 then "medium", else "small"
      assert ExCellerate.eval!(
               "abs(val) > 100 ? 'big' : (abs(val) > 10 ? 'medium' : 'small')",
               scope
             ) == "medium"
    end

    test "boolean logic across multiple scope values" do
      scope = %{"age" => 25, "has_license" => true, "is_insured" => false}

      assert ExCellerate.eval!(
               "age >= 18 && has_license && is_insured",
               scope
             ) == false

      assert ExCellerate.eval!(
               "age >= 18 && (has_license || is_insured)",
               scope
             ) == true
    end

    test "ifnull with nested access fallback chain" do
      scope = %{"user" => %{"nickname" => nil, "name" => "Alice"}}

      assert ExCellerate.eval!(
               "ifnull(user.nickname, user.name)",
               scope
             ) == "Alice"
    end

    test "modulo and arithmetic with ternary for even/odd" do
      scope = %{"n" => 17}

      assert ExCellerate.eval!("n % 2 == 0 ? 'even' : 'odd'", scope) == "odd"
      assert ExCellerate.eval!("(n + 1) % 2 == 0 ? 'even' : 'odd'", scope) == "even"
    end

    test "compiled function reused across different complex scopes" do
      {:ok, fun} =
        ExCellerate.compile(
          "abs(a - b) > threshold ? concat(label, ': ALERT') : concat(label, ': OK')"
        )

      assert fun.(%{"a" => 100, "b" => 50, "threshold" => 30, "label" => "Sensor1"}) ==
               "Sensor1: ALERT"

      assert fun.(%{"a" => 10, "b" => 12, "threshold" => 5, "label" => "Sensor2"}) ==
               "Sensor2: OK"
    end

    test "mixed dot and bracket access with computation" do
      scope = %{
        "data" => %{
          "matrix" => [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
        },
        "row" => 1,
        "col" => 2
      }

      assert ExCellerate.eval!("data.matrix[row][col]", scope) == 6
    end

    test "power and factorial with scope" do
      scope = %{"base" => 2, "exp" => 10}
      assert ExCellerate.eval!("base ^ exp", scope) == 1024.0
    end

    test "substring and contains on scope strings" do
      scope = %{"email" => "alice@example.com"}

      assert ExCellerate.eval!("contains(email, '@')", scope) == true
      assert ExCellerate.eval!("substring(email, 0, 5)", scope) == "alice"
    end

    test "normalize with concatenation from scope" do
      scope = %{"category" => "Office Supplies", "id" => 42}

      assert ExCellerate.eval!(
               "concat(normalize(category), '_', id)",
               scope
             ) == "office_supplies_42"
    end
  end

  # ── Struct access ────────────────────────────────────────────────

  describe "struct access" do
    test "struct fields accessible via dot notation in scope" do
      uri = URI.parse("https://example.com/path")
      scope = %{"uri" => uri}

      assert ExCellerate.eval!("uri.host", scope) == "example.com"
      assert ExCellerate.eval!("uri.scheme", scope) == "https"
      assert ExCellerate.eval!("uri.path", scope) == "/path"
    end

    test "struct as top-level scope with atom keys" do
      uri = URI.parse("https://example.com/path")
      assert ExCellerate.eval!("host", uri) == "example.com"
      assert ExCellerate.eval!("scheme", uri) == "https"
    end

    test "nested struct access" do
      scope = %{
        "config" => %{
          "endpoint" => URI.parse("https://api.example.com/v1")
        }
      }

      assert ExCellerate.eval!("config.endpoint.host", scope) == "api.example.com"
    end

    test "struct field in arithmetic expression" do
      scope = %{"uri" => URI.parse("https://example.com:8080")}
      assert ExCellerate.eval!("uri.port + 1", scope) == 8081
    end

    test "struct field in function call" do
      scope = %{"uri" => URI.parse("https://example.com/path")}
      assert ExCellerate.eval!("contains(uri.host, 'example')", scope) == true
    end

    test "struct field with ternary" do
      scope = %{"uri" => URI.parse("https://example.com")}

      assert ExCellerate.eval!(
               "uri.scheme == 'https' ? 'secure' : 'insecure'",
               scope
             ) == "secure"
    end
  end

  # ── Coverage: internal module edge cases ──────────────────────────

  describe "error formatting" do
    test "compiler error type has correct prefix" do
      error = ExCellerate.Error.exception(type: :compiler, message: "test")
      assert Exception.message(error) =~ "Compilation error"
      assert Exception.message(error) =~ "test"
    end

    test "error with line and column includes location" do
      error = ExCellerate.Error.exception(type: :parser, message: "bad", line: 1, column: 5)
      assert Exception.message(error) =~ "at line 1, column 5"
    end
  end

  describe "default function lookup" do
    test "get_default_function returns nil for unknown function" do
      assert ExCellerate.Functions.get_default_function("nonexistent_function") == nil
    end

    test "get_default_function returns module for known function" do
      assert ExCellerate.Functions.get_default_function("abs") ==
               ExCellerate.Functions.Math.Abs
    end
  end

  describe "compiler dispatch edge cases" do
    test "dispatch_call with non-callable value raises" do
      assert_raise ExCellerate.Error, ~r/not a function/, fn ->
        ExCellerate.Compiler.dispatch_call("not_a_function", [1])
      end
    end

    test "dispatch_call with nil raises" do
      assert_raise ExCellerate.Error, ~r/not a function/, fn ->
        ExCellerate.Compiler.dispatch_call(nil, [1])
      end
    end

    test "dispatch_call with module missing call/1 raises" do
      assert_raise ExCellerate.Error, ~r/not a function/, fn ->
        ExCellerate.Compiler.dispatch_call(String, [1])
      end
    end
  end

  # ── Bug regression tests (TDD: written before fixes) ──────────────

  describe "sentinel collision bug" do
    test "map value of :not_found is returned correctly" do
      scope = %{"m" => %{"k" => :not_found}}
      assert ExCellerate.eval!("m.k", scope) == :not_found
    end

    test "list value of :not_found is returned correctly" do
      scope = %{"l" => [:not_found, :ok]}
      assert ExCellerate.eval!("l[0]", scope) == :not_found
    end
  end

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

  # ── Operator precedence ──────────────────────────────────────────

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

  # ── Basic arithmetic (standalone) ────────────────────────────────

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

  # ── Parser error cases ──────────────────────────────────────────

  describe "parser errors" do
    test "empty string" do
      assert {:error, %ExCellerate.Error{type: :parser}} = ExCellerate.eval("")
    end

    test "unknown characters" do
      assert {:error, _} = ExCellerate.eval("1 @ 2")
    end

    test "trailing operator" do
      assert {:error, _} = ExCellerate.eval("1 + ")
    end

    test "mismatched parentheses" do
      assert {:error, _} = ExCellerate.eval("(1 + 2")
      assert {:error, _} = ExCellerate.eval("1 + 2)")
    end

    test "missing closing bracket" do
      assert {:error, _} = ExCellerate.eval("list[0")
    end

    test "missing function closing paren" do
      assert {:error, _} = ExCellerate.eval("abs(1")
    end
  end

  # ── Nested expressions ──────────────────────────────────────────

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

  # ── Public API ──────────────────────────────────────────────────

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

  # ── Compile to reusable function ─────────────────────────────────

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

  # ── Type mismatches and truthiness ──────────────────────────────

  describe "type edge cases" do
    test "nil in arithmetic returns error" do
      assert {:error, _} = ExCellerate.eval("a + 1", %{"a" => nil})
    end

    test "boolean in arithmetic returns error" do
      assert {:error, _} = ExCellerate.eval("true + 1")
    end

    test "ternary treats 0 as truthy (Elixir semantics)" do
      assert ExCellerate.eval!("0 ? 'yes' : 'no'") == "yes"
    end

    test "ternary treats empty string as truthy" do
      assert ExCellerate.eval!("'' ? 'yes' : 'no'") == "yes"
    end

    test "ternary treats null as falsy" do
      assert ExCellerate.eval!("null ? 'yes' : 'no'") == "no"
    end
  end

  # ── Whitespace and string edge cases ────────────────────────────

  describe "whitespace handling" do
    test "no whitespace around operators" do
      assert ExCellerate.eval!("1+2") == 3
      assert ExCellerate.eval!("3*4") == 12
    end

    test "extra whitespace around operators" do
      assert ExCellerate.eval!("  1  +  2  ") == 3
    end

    test "tabs as whitespace" do
      assert ExCellerate.eval!("1\t+\t2") == 3
    end

    test "newlines as whitespace" do
      assert ExCellerate.eval!("1\n+\n2") == 3
    end

    test "whitespace in function args" do
      assert ExCellerate.eval!("abs(  -10  )") == 10
    end
  end

  describe "string edge cases" do
    test "empty strings" do
      assert ExCellerate.eval!("''") == ""
      assert ExCellerate.eval!("\"\"") == ""
    end

    test "carriage return escape" do
      assert ExCellerate.eval!("'a\\rb'") == "a\rb"
    end
  end

  # ── Scope edge cases ────────────────────────────────────────────

  describe "scope edge cases" do
    test "string key takes precedence over atom key" do
      scope = %{"x" => 1, x: 2}
      assert ExCellerate.eval!("x", scope) == 1
    end

    test "non-function scope variable called as function returns error" do
      scope = %{"notfunc" => 42}
      assert {:error, _} = ExCellerate.eval("notfunc(1)", scope)
    end

    test "scope variable shadows builtin when not called as function" do
      scope = %{"abs" => 42}
      assert ExCellerate.eval!("abs", scope) == 42
    end

    test "negate a variable" do
      assert ExCellerate.eval!("-a", %{"a" => 5}) == -5
    end
  end

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
