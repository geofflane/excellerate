defmodule ExCellerate.FunctionsTest do
  use ExUnit.Case, async: true

  alias ExCellerate.Test.DoubleFuncRegistry
  alias ExCellerate.Test.OverrideRegistry

  describe "built-in math functions" do
    test "calls registered functions" do
      assert ExCellerate.eval!("abs(-10)") == 10
      assert ExCellerate.eval!("round(1.5)") == 2
      assert ExCellerate.eval!("max(10, 20)") == 20
      assert ExCellerate.eval!("min(10, 20)") == 10
      assert ExCellerate.eval!("ceil(1.2)") == 2
      assert ExCellerate.eval!("floor(1.9)") == 1
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
  end

  describe "built-in string functions" do
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

    test "calls normalize builtin" do
      assert ExCellerate.eval!("normalize('Hello World')") == "hello_world"
    end

    test "normalize with non-string returns value unchanged" do
      assert ExCellerate.eval!("normalize(42)", %{}) == 42
      assert ExCellerate.eval!("normalize(null)", %{}) == nil
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
end
