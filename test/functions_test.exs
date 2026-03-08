defmodule ExCellerate.FunctionsTest do
  use ExUnit.Case, async: true

  alias ExCellerate.Test.DoubleFuncRegistry
  alias ExCellerate.Test.OverrideRegistry

  describe "abs" do
    test "returns absolute value" do
      assert ExCellerate.eval!("abs(-10)") == 10
      assert ExCellerate.eval!("abs(5)") == 5
      assert ExCellerate.eval!("abs(-3.14)") == 3.14
    end

    test "rejects non-numeric input" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("abs('hello')")

      assert msg =~ "abs"
      assert msg =~ "number"
    end
  end

  describe "ceil" do
    test "rounds up to nearest integer" do
      assert ExCellerate.eval!("ceil(1.2)") == 2
      assert ExCellerate.eval!("ceil(3.0)") == 3
      assert ExCellerate.eval!("ceil(-1.7)") == -1
    end

    test "rejects non-numeric input" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("ceil('hello')")

      assert msg =~ "ceil"
      assert msg =~ "number"
    end
  end

  describe "floor" do
    test "rounds down to nearest integer" do
      assert ExCellerate.eval!("floor(1.9)") == 1
      assert ExCellerate.eval!("floor(3.0)") == 3
      assert ExCellerate.eval!("floor(-1.2)") == -2
    end

    test "rejects non-numeric input" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("floor('hello')")

      assert msg =~ "floor"
      assert msg =~ "number"
    end
  end

  describe "round" do
    test "rounds to nearest integer" do
      assert ExCellerate.eval!("round(1.5)") == 2
    end

    test "rounds with digits argument" do
      assert ExCellerate.eval!("round(3.14159, 2)") == 3.14
      assert ExCellerate.eval!("round(3.14159, 0)") == 3.0
      assert ExCellerate.eval!("round(3.14159, 4)") == 3.1416
      assert ExCellerate.eval!("round(42, 2)") == 42.0
      assert ExCellerate.eval!("round(2.5, 0)") == 3.0
    end

    test "negative digits truncates left of decimal" do
      assert ExCellerate.eval!("round(1234, -2)") == 1200.0
      assert ExCellerate.eval!("round(1250, -2)") == 1300.0
    end

    test "rejects non-numeric input" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("round('hello')")

      assert msg =~ "round"
      assert msg =~ "number"
    end

    test "rejects non-integer digits" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("round(3.14, 1.5)")

      assert msg =~ "round"
      assert msg =~ "integer"
    end
  end

  describe "trunc" do
    test "truncates toward zero" do
      assert ExCellerate.eval!("trunc(3.7)") == 3
      assert ExCellerate.eval!("trunc(-3.7)") == -3
      assert ExCellerate.eval!("trunc(5)") == 5
    end

    test "rejects non-numeric input" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("trunc('hello')")

      assert msg =~ "trunc"
      assert msg =~ "number"
    end
  end

  describe "sign" do
    test "returns sign of number" do
      assert ExCellerate.eval!("sign(-42)") == -1
      assert ExCellerate.eval!("sign(0)") == 0
      assert ExCellerate.eval!("sign(42)") == 1
      assert ExCellerate.eval!("sign(-0.5)") == -1
      assert ExCellerate.eval!("sign(0.001)") == 1
    end

    test "rejects non-numeric input" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("sign('hello')")

      assert msg =~ "sign"
      assert msg =~ "number"
    end
  end

  describe "sqrt" do
    test "returns square root" do
      assert ExCellerate.eval!("sqrt(9)") == 3.0
      assert ExCellerate.eval!("sqrt(2)") == :math.sqrt(2)
      assert ExCellerate.eval!("sqrt(0)") == 0.0
    end

    test "rejects negative number" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("sqrt(-1)")

      assert msg =~ "sqrt"
      assert msg =~ "non-negative number"
    end

    test "rejects non-numeric input" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("sqrt('hello')")

      assert msg =~ "sqrt"
      assert msg =~ "non-negative number"
    end
  end

  describe "exp" do
    test "returns e raised to power" do
      assert ExCellerate.eval!("exp(0)") == 1.0
      assert ExCellerate.eval!("exp(1)") == :math.exp(1)
    end

    test "rejects non-numeric input" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("exp('hello')")

      assert msg =~ "exp"
      assert msg =~ "number"
    end
  end

  describe "ln" do
    test "returns natural logarithm" do
      assert ExCellerate.eval!("ln(1)") == 0.0
      assert_in_delta ExCellerate.eval!("ln(2.718281828)"), 1.0, 0.0001
    end

    test "rejects non-numeric input" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("ln('hello')")

      assert msg =~ "ln"
      assert msg =~ "number"
    end
  end

  describe "log" do
    test "returns logarithm in specified base" do
      assert ExCellerate.eval!("log(8, 2)") == :math.log(8) / :math.log(2)
      assert ExCellerate.eval!("log(100, 10)") == :math.log(100) / :math.log(10)
    end

    test "rejects non-numeric value" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("log('hello', 2)")

      assert msg =~ "log"
      assert msg =~ "number"
    end

    test "rejects non-numeric base" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("log(8, 'two')")

      assert msg =~ "log"
      assert msg =~ "number"
    end
  end

  describe "log10" do
    test "returns base-10 logarithm" do
      assert ExCellerate.eval!("log10(100)") == 2.0
      assert ExCellerate.eval!("log10(1000)") == :math.log10(1000)
    end

    test "rejects non-numeric input" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("log10('hello')")

      assert msg =~ "log10"
      assert msg =~ "number"
    end
  end

  describe "sum" do
    test "sums values" do
      assert ExCellerate.eval!("sum(1, 2, 3)") == 6
      assert ExCellerate.eval!("sum(10)") == 10
      assert ExCellerate.eval!("sum(1, 2, 3, 4, 5)") == 15
      assert ExCellerate.eval!("sum(a, b, c)", %{"a" => 10, "b" => 20, "c" => 30}) == 60
    end

    test "rejects non-numeric input" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("sum(1, 'two', 3)")

      assert msg =~ "sum"
      assert msg =~ "number"
    end
  end

  describe "avg" do
    test "returns arithmetic mean" do
      assert ExCellerate.eval!("avg(2, 4, 6)") == 4.0
      assert ExCellerate.eval!("avg(10)") == 10.0
      assert ExCellerate.eval!("avg(1, 2)") == 1.5
    end

    test "rejects non-numeric input" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("avg(1, 'two', 3)")

      assert msg =~ "avg"
      assert msg =~ "number"
    end
  end

  describe "min" do
    test "returns smallest value" do
      assert ExCellerate.eval!("min(5)") == 5
      assert ExCellerate.eval!("min(3, 1, 2)") == 1
      assert ExCellerate.eval!("min(10, 20, 5, 15)") == 5
    end

    test "rejects non-numeric input" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("min(1, 'two', 3)")

      assert msg =~ "min"
      assert msg =~ "number"
    end
  end

  describe "max" do
    test "returns largest value" do
      assert ExCellerate.eval!("max(5)") == 5
      assert ExCellerate.eval!("max(3, 1, 2)") == 3
      assert ExCellerate.eval!("max(10, 20, 5, 15)") == 20
    end

    test "rejects non-numeric input" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("max(1, 'two', 3)")

      assert msg =~ "max"
      assert msg =~ "number"
    end
  end

  describe "built-in string functions" do
    test "calls len builtin" do
      assert ExCellerate.eval!("len('hello')") == 5
      assert ExCellerate.eval!("len('')") == 0
      assert ExCellerate.eval!("len(name)", %{"name" => "Alice"}) == 5
    end

    test "len with non-string non-list returns error" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("len(1)")

      assert msg =~ "len"
      assert msg =~ "string or list"
    end

    test "calls left builtin" do
      assert ExCellerate.eval!("left('Hello World', 5)") == "Hello"
      assert ExCellerate.eval!("left('Hi', 10)") == "Hi"
      assert ExCellerate.eval!("left('Hello', 0)") == ""
    end

    test "left with no count defaults to 1 character" do
      assert ExCellerate.eval!("left('Hello')") == "H"
      assert ExCellerate.eval!("left('A')") == "A"
      assert ExCellerate.eval!("left('')") == ""
    end

    test "calls right builtin" do
      assert ExCellerate.eval!("right('Hello World', 5)") == "World"
      assert ExCellerate.eval!("right('Hi', 10)") == "Hi"
      assert ExCellerate.eval!("right('Hello', 0)") == ""
    end

    test "right with no count defaults to 1 character" do
      assert ExCellerate.eval!("right('Hello')") == "o"
      assert ExCellerate.eval!("right('A')") == "A"
      assert ExCellerate.eval!("right('')") == ""
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

    test "find with start_pos argument" do
      assert ExCellerate.eval!("find('o', 'hello world', 5)") == 7
      assert ExCellerate.eval!("find('l', 'hello world', 4)") == 9
      assert ExCellerate.eval!("find('xyz', 'hello', 0)") == -1
    end

    test "calls concat builtin" do
      assert ExCellerate.eval!("concat('foo', 'bar')") == "foobar"
      assert ExCellerate.eval!("concat('a', 1, true)") == "a1true"
    end

    test "calls contains builtin" do
      assert ExCellerate.eval!("contains('Hello World', 'World')") == true
      assert ExCellerate.eval!("contains('Hello World', 'Foo')") == false
    end

    test "contains returns false for non-string args" do
      assert ExCellerate.eval!("contains(123, 'foo')", %{}) == false
      assert ExCellerate.eval!("contains(null, 'foo')", %{}) == false
    end

    test "calls substring builtin" do
      assert ExCellerate.eval!("substring('Hello World', 6)") == "World"
      assert ExCellerate.eval!("substring('Hello World', 0, 5)") == "Hello"
    end

    test "substring with non-string returns nil" do
      assert ExCellerate.eval!("substring(123, 0)", %{}) == nil
    end

    test "substring rejects wrong number of args" do
      assert {:error, %ExCellerate.Error{type: :compiler, message: msg}} =
               ExCellerate.eval("substring('hello')")

      assert msg =~ "substring"
      assert msg =~ "2..3"

      assert {:error, %ExCellerate.Error{type: :compiler, message: msg}} =
               ExCellerate.eval("substring('hello', 0, 5, 'extra')")

      assert msg =~ "substring"
    end

    test "calls underscore builtin" do
      assert ExCellerate.eval!("underscore('Hello World')") == "hello_world"
    end

    test "underscore replaces slashes with underscores" do
      assert ExCellerate.eval!("underscore('Hello/World')") == "hello_world"
    end

    test "underscore strips non-alphanumeric characters" do
      assert ExCellerate.eval!("underscore('Hello! @World#')") == "hello_world"
    end

    test "underscore with non-string raises" do
      assert {:error, %ExCellerate.Error{type: :runtime}} =
               ExCellerate.eval("underscore(42)")

      assert {:error, %ExCellerate.Error{type: :runtime}} =
               ExCellerate.eval("underscore(null)")
    end

    test "calls slug builtin" do
      assert ExCellerate.eval!("slug('Hello World')") == "hello-world"
    end

    test "slug replaces slashes with hyphens" do
      assert ExCellerate.eval!("slug('Hello/World')") == "hello-world"
    end

    test "slug strips non-alphanumeric characters" do
      assert ExCellerate.eval!("slug('Hello! @World#')") == "hello-world"
    end

    test "slug with non-string raises" do
      assert {:error, %ExCellerate.Error{type: :runtime}} =
               ExCellerate.eval("slug(42)")

      assert {:error, %ExCellerate.Error{type: :runtime}} =
               ExCellerate.eval("slug(null)")
    end
  end

  describe "built-in utility functions" do
    test "calls ifnull builtin" do
      assert ExCellerate.eval!("ifnull(a, 0)", %{"a" => nil}) == 0
      assert ExCellerate.eval!("ifnull(a, 0)", %{"a" => 10}) == 10
    end

    test "calls if builtin" do
      assert ExCellerate.eval!("if(true, 1, 0)") == 1
      assert ExCellerate.eval!("if(false, 1, 0)") == 0
    end

    test "if with two args defaults else to nil" do
      assert ExCellerate.eval!("if(true, 'yes')") == "yes"
      assert ExCellerate.eval!("if(false, 'yes')") == nil
      assert ExCellerate.eval!("if(null, 42)") == nil
    end

    test "isnull returns true for null values" do
      assert ExCellerate.eval!("isnull(null)") == true
      assert ExCellerate.eval!("isnull(a)", %{"a" => nil}) == true
    end

    test "isnull returns false for non-null values" do
      assert ExCellerate.eval!("isnull(0)") == false
      assert ExCellerate.eval!("isnull('')") == false
      assert ExCellerate.eval!("isnull(false)") == false
      assert ExCellerate.eval!("isnull('hello')") == false
      assert ExCellerate.eval!("isnull(42)") == false
    end

    test "isnull works in expressions" do
      scope = %{"val" => nil}
      assert ExCellerate.eval!("isnull(val) ? 'missing' : 'present'", scope) == "missing"
    end

    test "isblank returns true for null and empty strings" do
      assert ExCellerate.eval!("isblank(null)") == true
      assert ExCellerate.eval!("isblank('')") == true
      assert ExCellerate.eval!("isblank(a)", %{"a" => nil}) == true
      assert ExCellerate.eval!("isblank(a)", %{"a" => ""}) == true
    end

    test "isblank returns true for whitespace-only strings" do
      assert ExCellerate.eval!("isblank(a)", %{"a" => "  "}) == true
      assert ExCellerate.eval!("isblank(a)", %{"a" => "\t\n"}) == true
    end

    test "isblank returns false for non-blank values" do
      assert ExCellerate.eval!("isblank(0)") == false
      assert ExCellerate.eval!("isblank(false)") == false
      assert ExCellerate.eval!("isblank('hello')") == false
      assert ExCellerate.eval!("isblank(42)") == false
      assert ExCellerate.eval!("isblank(' x ')") == false
    end

    test "isblank works in expressions" do
      scope = %{"name" => "  "}
      assert ExCellerate.eval!("isblank(name) ? 'Anonymous' : trim(name)", scope) == "Anonymous"
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

    test "lookup rejects wrong number of args" do
      scope = %{"m" => %{"k" => 1}}

      assert {:error, %ExCellerate.Error{type: :compiler, message: msg}} =
               ExCellerate.eval("lookup(m)", scope)

      assert msg =~ "lookup"
      assert msg =~ "2..3"

      assert {:error, %ExCellerate.Error{type: :compiler, message: msg}} =
               ExCellerate.eval("lookup(m, 'k', 'd', 'extra')", scope)

      assert msg =~ "lookup"
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
  end

  describe "take" do
    setup do
      scope = %{
        "grid" => [
          [1, 2, 3, 4],
          [5, 6, 7, 8],
          [9, 10, 11, 12],
          [13, 14, 15, 16]
        ]
      }

      %{scope: scope}
    end

    test "takes first N rows with positive count", %{scope: scope} do
      assert ExCellerate.eval!("take(grid, 2)", scope) == [
               [1, 2, 3, 4],
               [5, 6, 7, 8]
             ]
    end

    test "takes last N rows with negative count", %{scope: scope} do
      assert ExCellerate.eval!("take(grid, -2)", scope) == [
               [9, 10, 11, 12],
               [13, 14, 15, 16]
             ]
    end

    test "takes all rows when count exceeds length", %{scope: scope} do
      assert ExCellerate.eval!("take(grid, 10)", scope) == scope["grid"]
    end

    test "takes all rows when negative count exceeds length", %{scope: scope} do
      assert ExCellerate.eval!("take(grid, -10)", scope) == scope["grid"]
    end

    test "takes first N columns with null rows", %{scope: scope} do
      assert ExCellerate.eval!("take(grid, null, 2)", scope) == [
               [1, 2],
               [5, 6],
               [9, 10],
               [13, 14]
             ]
    end

    test "takes last N columns with negative count", %{scope: scope} do
      assert ExCellerate.eval!("take(grid, null, -2)", scope) == [
               [3, 4],
               [7, 8],
               [11, 12],
               [15, 16]
             ]
    end

    test "takes all columns when count exceeds width", %{scope: scope} do
      assert ExCellerate.eval!("take(grid, null, 10)", scope) == scope["grid"]
    end

    test "takes first N rows and first M columns", %{scope: scope} do
      assert ExCellerate.eval!("take(grid, 2, 2)", scope) == [
               [1, 2],
               [5, 6]
             ]
    end

    test "takes last N rows and first M columns", %{scope: scope} do
      assert ExCellerate.eval!("take(grid, -2, 2)", scope) == [
               [9, 10],
               [13, 14]
             ]
    end

    test "takes first N rows and last M columns", %{scope: scope} do
      assert ExCellerate.eval!("take(grid, 2, -2)", scope) == [
               [3, 4],
               [7, 8]
             ]
    end

    test "takes last N rows and last M columns", %{scope: scope} do
      assert ExCellerate.eval!("take(grid, -2, -2)", scope) == [
               [11, 12],
               [15, 16]
             ]
    end

    test "takes first N elements from a flat list" do
      scope = %{"items" => [10, 20, 30, 40, 50]}
      assert ExCellerate.eval!("take(items, 3)", scope) == [10, 20, 30]
    end

    test "takes last N elements from a flat list" do
      scope = %{"items" => [10, 20, 30, 40, 50]}
      assert ExCellerate.eval!("take(items, -3)", scope) == [30, 40, 50]
    end

    test "zero rows returns empty list" do
      scope = %{"data" => [[1, 2], [3, 4]]}
      assert ExCellerate.eval!("take(data, 0)", scope) == []
    end

    test "zero columns returns empty rows" do
      scope = %{"data" => [[1, 2], [3, 4]]}
      assert ExCellerate.eval!("take(data, null, 0)", scope) == [[], []]
    end

    test "empty list returns empty list" do
      scope = %{"data" => []}
      assert ExCellerate.eval!("take(data, 3)", scope) == []
    end

    test "rejects non-list first argument" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("take(42, 2)")

      assert msg =~ "take"
      assert msg =~ "list"
    end

    test "rejects non-integer row count" do
      scope = %{"data" => [[1, 2]]}

      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("take(data, 1.5)", scope)

      assert msg =~ "take"
      assert msg =~ "integer"
    end

    test "rejects non-integer column count" do
      scope = %{"data" => [[1, 2]]}

      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("take(data, null, 1.5)", scope)

      assert msg =~ "take"
      assert msg =~ "integer"
    end

    test "rejects wrong arity" do
      assert {:error, %ExCellerate.Error{type: :compiler}} =
               ExCellerate.eval("take()")

      assert {:error, %ExCellerate.Error{type: :compiler}} =
               ExCellerate.eval("take(data, 1, 2, 3)")
    end
  end

  describe "slice" do
    test "slices from start index to end of list" do
      scope = %{"items" => [10, 20, 30, 40, 50]}
      assert ExCellerate.eval!("slice(items, 1)", scope) == [20, 30, 40, 50]
    end

    test "slices from start index with length" do
      scope = %{"items" => [10, 20, 30, 40, 50]}
      assert ExCellerate.eval!("slice(items, 1, 3)", scope) == [20, 30, 40]
    end

    test "slices from beginning" do
      scope = %{"items" => [10, 20, 30, 40, 50]}
      assert ExCellerate.eval!("slice(items, 0, 2)", scope) == [10, 20]
    end

    test "slices a single element" do
      scope = %{"items" => [10, 20, 30]}
      assert ExCellerate.eval!("slice(items, 1, 1)", scope) == [20]
    end

    test "negative start counts from end" do
      scope = %{"items" => [10, 20, 30, 40, 50]}
      assert ExCellerate.eval!("slice(items, -2)", scope) == [40, 50]
    end

    test "negative start with length" do
      scope = %{"items" => [10, 20, 30, 40, 50]}
      assert ExCellerate.eval!("slice(items, -3, 2)", scope) == [30, 40]
    end

    test "start beyond end returns empty list" do
      scope = %{"items" => [10, 20, 30]}
      assert ExCellerate.eval!("slice(items, 10)", scope) == []
    end

    test "length exceeding remaining elements is clamped" do
      scope = %{"items" => [10, 20, 30]}
      assert ExCellerate.eval!("slice(items, 1, 100)", scope) == [20, 30]
    end

    test "length of zero returns empty list" do
      scope = %{"items" => [10, 20, 30]}
      assert ExCellerate.eval!("slice(items, 1, 0)", scope) == []
    end

    test "empty list returns empty list" do
      scope = %{"items" => []}
      assert ExCellerate.eval!("slice(items, 0)", scope) == []
    end

    test "negative start beyond beginning clamps to zero" do
      scope = %{"items" => [10, 20, 30]}
      assert ExCellerate.eval!("slice(items, -10, 2)", scope) == [10, 20]
    end

    test "rejects non-list first argument" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("slice(42, 1)")

      assert msg =~ "slice"
      assert msg =~ "list"
    end

    test "rejects non-integer start" do
      scope = %{"items" => [1, 2, 3]}

      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("slice(items, 1.5)", scope)

      assert msg =~ "slice"
      assert msg =~ "integer"
    end

    test "rejects non-integer length" do
      scope = %{"items" => [1, 2, 3]}

      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("slice(items, 0, 1.5)", scope)

      assert msg =~ "slice"
      assert msg =~ "integer"
    end

    test "rejects negative length" do
      scope = %{"items" => [1, 2, 3]}

      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("slice(items, 0, -1)", scope)

      assert msg =~ "slice"
      assert msg =~ "non-negative"
    end

    test "rejects wrong arity" do
      assert {:error, %ExCellerate.Error{type: :compiler}} =
               ExCellerate.eval("slice(items)")

      assert {:error, %ExCellerate.Error{type: :compiler}} =
               ExCellerate.eval("slice(items, 0, 1, 2)")
    end
  end

  describe "ifs function" do
    test "returns value for first true condition" do
      scope = %{"score" => 85}

      assert ExCellerate.eval!("ifs(score > 90, 'A', score > 80, 'B', score > 70, 'C')", scope) ==
               "B"
    end

    test "stops at first true condition (order matters)" do
      scope = %{"x" => 100}
      assert ExCellerate.eval!("ifs(x > 50, 'first', x > 90, 'second')", scope) == "first"
    end

    test "true as final condition acts as default" do
      scope = %{"score" => 50}

      assert ExCellerate.eval!(
               "ifs(score > 90, 'A', score > 80, 'B', true, 'C')",
               scope
             ) == "C"
    end

    test "returns nil when no conditions are met" do
      scope = %{"x" => 1}
      assert ExCellerate.eval!("ifs(x > 10, 'big', x > 5, 'medium')", scope) == nil
    end

    test "works with single condition/value pair" do
      assert ExCellerate.eval!("ifs(true, 'yes')") == "yes"
      assert ExCellerate.eval!("ifs(false, 'yes')") == nil
    end

    test "works with expressions as conditions and values" do
      scope = %{"a" => 3, "b" => 7}

      assert ExCellerate.eval!("ifs(a > b, a * 10, b > a, b * 10)", scope) == 70
    end

    test "rejects odd number of arguments" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("ifs(true, 'a', false)")

      assert msg =~ "ifs"
      assert msg =~ "even"
    end

    test "rejects zero arguments" do
      assert {:error, %ExCellerate.Error{type: :runtime, message: msg}} =
               ExCellerate.eval("ifs()")

      assert msg =~ "ifs"
    end
  end

  describe "custom functions via registry" do
    test "supports global registration via Registry" do
      assert DoubleFuncRegistry.eval!("double(5)") == 10
      # Defaults still work
      assert DoubleFuncRegistry.eval!("abs(-5)") == 5
    end

    test "registry allows overriding defaults globally" do
      assert OverrideRegistry.eval!("abs(-10)") == 42
    end

    test "scope functions are not supported — use a registry" do
      scope = %{"custom" => fn x -> x * 2 end}

      assert {:error, %ExCellerate.Error{type: :compiler, message: msg}} =
               ExCellerate.eval("custom(21)", scope)

      assert msg =~ "unknown function"
    end
  end

  describe "list_functions/0" do
    test "returns a list of modules" do
      functions = DoubleFuncRegistry.list_functions()
      assert is_list(functions)
      assert length(functions) > 0

      Enum.each(functions, fn mod ->
        assert is_atom(mod)
        assert function_exported?(mod, :name, 0)
        assert function_exported?(mod, :arity, 0)
        assert function_exported?(mod, :call, 1)
      end)
    end

    test "includes custom plugin functions" do
      functions = DoubleFuncRegistry.list_functions()
      assert ExCellerate.Test.DoubleFuncRegistry.Double in functions
    end

    test "includes default built-in functions" do
      functions = DoubleFuncRegistry.list_functions()
      assert ExCellerate.Functions.Math.Abs in functions
    end

    test "plugins override defaults with the same name" do
      functions = OverrideRegistry.list_functions()
      abs_modules = Enum.filter(functions, &(&1.name() == "abs"))

      # Only one entry for "abs" — the override, not both
      assert length(abs_modules) == 1
      assert hd(abs_modules) == ExCellerate.Test.OverrideRegistry.MyAbs
    end

    test "each function name appears exactly once" do
      functions = DoubleFuncRegistry.list_functions()
      names = Enum.map(functions, & &1.name())

      assert names == Enum.uniq(names)
    end

    test "total count equals defaults plus plugins (minus overrides)" do
      default_count = length(ExCellerate.Functions.list_defaults())
      functions = DoubleFuncRegistry.list_functions()

      # DoubleFuncRegistry adds 1 plugin ("double") that doesn't overlap defaults
      assert length(functions) == default_count + 1
    end

    test "modules can be introspected for name and arity" do
      functions = DoubleFuncRegistry.list_functions()
      double = Enum.find(functions, &(&1.name() == "double"))

      assert double.name() == "double"
      assert double.arity() == 1
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
               ExCellerate.eval("replace('hello', 'h')")

      assert msg =~ "replace"
      assert msg =~ "3"
      assert msg =~ "2"
    end

    test "allows variadic functions with any number of args" do
      assert ExCellerate.eval!("concat('a')") == "a"
      assert ExCellerate.eval!("concat('a', 'b', 'c')") == "abc"
    end

    test "accepts args within range arity bounds" do
      # round has arity 1..2 — both 1 and 2 args should compile
      assert ExCellerate.eval!("round(1.5)") == 2
      assert ExCellerate.eval!("round(1.5, 1)") == 1.5
    end

    test "rejects too many args for range-arity function" do
      assert {:error, %ExCellerate.Error{type: :compiler, message: msg}} =
               ExCellerate.eval("round(1, 2, 3)")

      assert msg =~ "round"
      assert msg =~ "1..2"
      assert msg =~ "3"
    end

    test "validate catches range arity errors" do
      assert {:error, %ExCellerate.Error{type: :compiler}} =
               ExCellerate.validate("round(1, 2, 3)")
    end

    test "validates arity through a registry" do
      assert {:error, %ExCellerate.Error{type: :compiler, message: msg}} =
               DoubleFuncRegistry.eval("double(1, 2)")

      assert msg =~ "double"
    end

    test "validate/2 catches arity errors without executing" do
      assert {:error, %ExCellerate.Error{type: :compiler}} =
               ExCellerate.validate("abs(1, 2)")
    end

    test "rejects unknown function names at compile time" do
      assert {:error, %ExCellerate.Error{type: :compiler, message: msg}} =
               ExCellerate.eval("invalid(1, 2)")

      assert msg =~ "invalid"
    end

    test "validate rejects unknown function names" do
      assert {:error, %ExCellerate.Error{type: :compiler, message: msg}} =
               ExCellerate.validate("invalid(1, 2)")

      assert msg =~ "invalid"
    end
  end

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

  describe "match function" do
    test "exact match in a list of numbers (default match_type)" do
      scope = %{"items" => [10, 20, 30, 40, 50]}
      assert ExCellerate.eval!("match(30, items)", scope) == 2
    end

    test "exact match at position 0" do
      scope = %{"items" => [10, 20, 30]}
      assert ExCellerate.eval!("match(10, items)", scope) == 0
    end

    test "exact match at last position" do
      scope = %{"items" => [10, 20, 30]}
      assert ExCellerate.eval!("match(30, items)", scope) == 2
    end

    test "returns nil when no exact match found" do
      scope = %{"items" => [10, 20, 30]}
      assert ExCellerate.eval!("match(99, items)", scope) == nil
    end

    test "exact match in string list" do
      scope = %{"fruits" => ["Apples", "Bananas", "Oranges"]}
      assert ExCellerate.eval!("match('Bananas', fruits)", scope) == 1
    end

    test "returns first match when duplicates exist" do
      scope = %{"items" => [10, 20, 10, 30]}
      assert ExCellerate.eval!("match(10, items)", scope) == 0
    end

    test "matches nil value" do
      scope = %{"items" => [1, nil, 3]}
      assert ExCellerate.eval!("match(null, items)", scope) == 1
    end

    test "matches boolean values" do
      scope = %{"items" => [false, true, false]}
      assert ExCellerate.eval!("match(true, items)", scope) == 1
    end

    test "explicit match_type 0 finds exact match" do
      scope = %{"items" => [25, 38, 40, 41]}
      assert ExCellerate.eval!("match(40, items, 0)", scope) == 2
    end

    test "explicit match_type 0 returns nil on no match" do
      scope = %{"items" => [25, 38, 40, 41]}
      assert ExCellerate.eval!("match(39, items, 0)", scope) == nil
    end

    test "match_type 1 finds exact match in ascending list" do
      scope = %{"items" => [10, 20, 30, 40]}
      assert ExCellerate.eval!("match(30, items, 1)", scope) == 2
    end

    test "match_type 1 finds largest value <= lookup_value" do
      scope = %{"items" => [10, 20, 30, 40]}
      assert ExCellerate.eval!("match(25, items, 1)", scope) == 1
    end

    test "match_type 1 returns nil when lookup_value is less than all items" do
      scope = %{"items" => [10, 20, 30]}
      assert ExCellerate.eval!("match(5, items, 1)", scope) == nil
    end

    test "match_type 1 matches last element when lookup_value exceeds all" do
      scope = %{"items" => [10, 20, 30]}
      assert ExCellerate.eval!("match(100, items, 1)", scope) == 2
    end

    test "match_type 1 with float values" do
      scope = %{"items" => [1.0, 2.5, 5.0, 7.5]}
      assert ExCellerate.eval!("match(3.0, items, 1)", scope) == 1
    end

    test "match_type -1 finds exact match in descending list" do
      scope = %{"items" => [40, 30, 20, 10]}
      assert ExCellerate.eval!("match(30, items, -1)", scope) == 1
    end

    test "match_type -1 finds smallest value >= lookup_value" do
      scope = %{"items" => [40, 30, 20, 10]}
      assert ExCellerate.eval!("match(25, items, -1)", scope) == 1
    end

    test "match_type -1 returns nil when lookup_value exceeds all items" do
      scope = %{"items" => [40, 30, 20, 10]}
      assert ExCellerate.eval!("match(50, items, -1)", scope) == nil
    end

    test "match_type -1 matches last element when lookup_value is less than all" do
      scope = %{"items" => [40, 30, 20, 10]}
      assert ExCellerate.eval!("match(5, items, -1)", scope) == 3
    end

    test "match on spread column values" do
      scope = %{
        "products" => [
          %{"name" => "Bananas", "count" => 25},
          %{"name" => "Oranges", "count" => 38},
          %{"name" => "Apples", "count" => 40}
        ]
      }

      assert ExCellerate.eval!("match('Oranges', products[*].name)", scope) == 1
    end

    test "raises on non-list lookup_array" do
      assert {:error, %ExCellerate.Error{type: :runtime}} =
               ExCellerate.eval("match(1, 'not a list')")
    end

    test "raises on invalid match_type" do
      scope = %{"items" => [1, 2, 3]}

      assert {:error, %ExCellerate.Error{type: :runtime}} =
               ExCellerate.eval("match(1, items, 2)", scope)
    end
  end

  describe "index function" do
    test "returns element at given position in 1D list" do
      scope = %{"items" => [10, 20, 30, 40, 50]}
      assert ExCellerate.eval!("index(items, 0)", scope) == 10
      assert ExCellerate.eval!("index(items, 2)", scope) == 30
      assert ExCellerate.eval!("index(items, 4)", scope) == 50
    end

    test "returns nil for out-of-bounds index" do
      scope = %{"items" => [10, 20, 30]}
      assert ExCellerate.eval!("index(items, 5)", scope) == nil
    end

    test "returns nil for negative index" do
      scope = %{"items" => [10, 20, 30]}
      assert ExCellerate.eval!("index(items, -1)", scope) == nil
    end

    test "works with string lists" do
      scope = %{"fruits" => ["Apples", "Bananas", "Oranges"]}
      assert ExCellerate.eval!("index(fruits, 1)", scope) == "Bananas"
    end

    test "returns element at row and column in 2D array" do
      scope = %{
        "grid" => [
          ["a", "b", "c"],
          ["d", "e", "f"],
          ["g", "h", "i"]
        ]
      }

      assert ExCellerate.eval!("index(grid, 0, 0)", scope) == "a"
      assert ExCellerate.eval!("index(grid, 1, 1)", scope) == "e"
      assert ExCellerate.eval!("index(grid, 2, 2)", scope) == "i"
    end

    test "returns nil for out-of-bounds row in 2D array" do
      scope = %{"grid" => [[1, 2], [3, 4]]}
      assert ExCellerate.eval!("index(grid, 5, 0)", scope) == nil
    end

    test "returns nil for out-of-bounds column in 2D array" do
      scope = %{"grid" => [[1, 2], [3, 4]]}
      assert ExCellerate.eval!("index(grid, 0, 5)", scope) == nil
    end

    test "works with numeric 2D arrays" do
      scope = %{
        "data" => [
          [100, 200, 300],
          [400, 500, 600]
        ]
      }

      assert ExCellerate.eval!("index(data, 0, 2)", scope) == 300
      assert ExCellerate.eval!("index(data, 1, 0)", scope) == 400
    end

    test "raises on non-list array" do
      assert {:error, %ExCellerate.Error{type: :runtime}} =
               ExCellerate.eval("index('not a list', 0)")
    end

    test "raises on non-integer row_num" do
      scope = %{"items" => [1, 2, 3]}

      assert {:error, %ExCellerate.Error{type: :runtime}} =
               ExCellerate.eval("index(items, 'a')", scope)
    end

    test "raises on non-integer column_num" do
      scope = %{"grid" => [[1, 2], [3, 4]]}

      assert {:error, %ExCellerate.Error{type: :runtime}} =
               ExCellerate.eval("index(grid, 0, 'a')", scope)
    end
  end

  describe "match + index composition" do
    test "index/match pattern — look up value by key column" do
      scope = %{
        "products" => [
          %{"name" => "Bananas", "price" => 1.25},
          %{"name" => "Oranges", "price" => 2.50},
          %{"name" => "Apples", "price" => 1.75}
        ]
      }

      assert ExCellerate.eval!(
               "index(products[*].price, match('Oranges', products[*].name))",
               scope
             ) == 2.50
    end

    test "index/match with 2D grid" do
      scope = %{
        "headers" => ["Q1", "Q2", "Q3", "Q4"],
        "data" => [
          [100, 200, 300, 400],
          [150, 250, 350, 450]
        ]
      }

      assert ExCellerate.eval!(
               "index(data[0], match('Q3', headers))",
               scope
             ) == 300
    end

    test "index/match returns nil when match fails" do
      scope = %{
        "names" => ["Alice", "Bob", "Carol"],
        "scores" => [90, 85, 92]
      }

      assert ExCellerate.eval!(
               "index(scores, match('Dave', names))",
               scope
             ) == nil
    end
  end
end
