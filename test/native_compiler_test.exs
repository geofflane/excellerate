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

    test "catches compiler-phase errors (unknown function) as the error contract" do
      assert {:error, %ExCellerate.Error{type: :compiler}} =
               NativeCompiler.compile("unknown_func(1)")
    end
  end

  describe "parity across a representative corpus" do
    @corpus [
      {"1 + 2 * 3 / (4 - 1)", %{}},
      {"a > 10 && b < 20 ? 'valid' : 'invalid'", %{"a" => 15, "b" => 5}},
      {"abs(-10) + round(1.5) + max(10, 20)", %{}},
      {"upper(concat('a', name))", %{"name" => "bc"}},
      {"sum(orders[*].price)", %{"orders" => [%{"price" => 10}, %{"price" => 25}]}},
      {"let(x, 5, x * x)", %{}},
      {"5!", %{}}
    ]

    for {expr, scope} <- @corpus do
      test "native matches interpreted for #{expr}" do
        {:ok, native} = NativeCompiler.compile(unquote(expr))
        {:ok, interpreted} = ExCellerate.compile(unquote(expr))

        assert native.(unquote(Macro.escape(scope))) ==
                 interpreted.(unquote(Macro.escape(scope)))
      end
    end
  end

  describe "compile_cached/3 (GenServer)" do
    alias ExCellerate.{Compiler, NativeCompiler, Parser}

    defp elixir_ast!(expr) do
      {:ok, ast} = Parser.parse(expr)
      Compiler.compile(ast)
    end

    test "compiles to a native module and returns its name" do
      start_supervised!({NativeCompiler, native_module_limit: 8})
      {:ok, fun, mod} = NativeCompiler.compile_cached(nil, "1 + 2", elixir_ast!("1 + 2"))

      assert Function.info(fun)[:type] == :external
      assert mod |> Atom.to_string() |> String.starts_with?("Elixir.ExCellerate.Compiled.S")
      assert fun.(%{}) == 3
    end

    test "dedups: same {registry, expr} reuses the same module" do
      start_supervised!({NativeCompiler, native_module_limit: 8})
      {:ok, _f1, mod1} = NativeCompiler.compile_cached(nil, "7 * 6", elixir_ast!("7 * 6"))
      {:ok, _f2, mod2} = NativeCompiler.compile_cached(nil, "7 * 6", elixir_ast!("7 * 6"))
      assert mod1 == mod2
    end

    test "falls back to an interpreted closure when the pool is full" do
      start_supervised!({NativeCompiler, native_module_limit: 1})
      {:ok, _f1, mod1} = NativeCompiler.compile_cached(nil, "1 + 1", elixir_ast!("1 + 1"))
      assert is_atom(mod1) and mod1 != nil

      {:ok, f2, mod2} = NativeCompiler.compile_cached(nil, "2 + 2", elixir_ast!("2 + 2"))
      assert mod2 == nil
      assert Function.info(f2)[:module] == :erl_eval
      assert f2.(%{}) == 4
    end

    test "the standalone compile/2 helper still works (Phase 1 unaffected)" do
      {:ok, fun} = NativeCompiler.compile("3 + 4")
      assert fun.(%{}) == 7

      assert Function.info(fun)[:module]
             |> Atom.to_string()
             |> String.starts_with?("Elixir.ExCellerate.Compiled.E")
    end
  end
end
