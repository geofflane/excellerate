defmodule ExCellerate.NativeCompilerTest do
  use ExUnit.Case, async: true

  alias ExCellerate.NativeCompiler

  describe "compile/2" do
    test "native-compiled eval matches the interpreted result" do
      expr = "abs(-10) + round(1.5) + max(10, 20)"
      {:ok, native} = NativeCompiler.compile(expr)
      {:ok, interpreted} = ExCellerate.compile(expr)
      assert native.(%{}) == interpreted.(%{})
    end

    test "evaluates against a scope like the interpreted path" do
      {:ok, native} = NativeCompiler.compile("user.profile.zip")
      assert native.(%{"user" => %{"profile" => %{"zip" => "12345"}}}) == "12345"
    end

    test "the returned function runs as a real loaded module, not the interpreter" do
      {:ok, native} = NativeCompiler.compile("1 + 2")
      info = Function.info(native)
      assert info[:type] == :external

      assert info[:module]
             |> Atom.to_string()
             |> String.starts_with?("Elixir.ExCellerate.Compiled")
    end

    test "contrast: the interpreted path runs in the erlang interpreter" do
      {:ok, interpreted} = ExCellerate.compile("1 + 2")
      assert Function.info(interpreted)[:module] == :erl_eval
    end

    test "returns the same error contract as the interpreted path on bad input" do
      assert {:error, %ExCellerate.Error{type: :parser}} = NativeCompiler.compile("1 +")
    end
  end
end
