defmodule ExCellerate.ParserTest do
  use ExUnit.Case, async: true

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
end
