defmodule ExCellerate.NativeCompilerTest do
  # async: false — these tests register a globally-named ExCellerate.NativeCompiler
  # process, which ExCellerate.compile/2 consults. Running concurrently with other
  # test files that call ExCellerate.eval/compile would let those calls dispatch
  # into a NativeCompiler that is mid-shutdown, exiting their GenServer.call.
  use ExUnit.Case, async: false

  alias ExCellerate.NativeCompiler
  import ExCellerate.Test.{Eventually, NativeAssertions}
  import ExUnit.CaptureLog

  defmodule BlockReg do
    @moduledoc false
    defmodule Block do
      @moduledoc false
      # block(pid): tells `pid` it is running, then waits for :unblock. Lets a
      # test hold a native eval frame on a process's stack for exactly as long
      # as it needs, with no timing assumptions.
      @behaviour ExCellerate.Function
      def name, do: "block"
      def arity, do: 1

      def call([pid]) do
        send(pid, {:blocked, self()})

        receive do
          :unblock -> 0
        end
      end
    end

    use ExCellerate.Registry, plugins: [Block]
  end

  # These tests drive the pool directly; a stale slot is only exercised by the
  # tests that pass their own on_stale.
  defp compile_cached(registry, expr, elixir_ast) do
    NativeCompiler.compile_cached(registry, expr, elixir_ast, fn _scope ->
      flunk("unexpected stale slot for #{expr}")
    end)
  end

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
      assert_native(native, "Elixir.ExCellerate.Compiled.E")
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

  describe "compile_cached/4 (GenServer)" do
    alias ExCellerate.{Compiler, NativeCompiler, Parser}

    defp elixir_ast!(expr) do
      {:ok, ast} = Parser.parse(expr)
      Compiler.compile(ast)
    end

    test "compiles to a native module and returns its name" do
      start_supervised!({NativeCompiler, native_module_limit: 8})
      {:ok, fun, mod} = compile_cached(nil, "1 + 2", elixir_ast!("1 + 2"))

      assert_native(fun)
      assert mod |> Atom.to_string() |> String.starts_with?("Elixir.ExCellerate.Compiled.S")
      assert fun.(%{}) == 3
    end

    test "dedups: same {registry, expr} reuses the same module" do
      start_supervised!({NativeCompiler, native_module_limit: 8})
      {:ok, _f1, mod1} = compile_cached(nil, "7 * 6", elixir_ast!("7 * 6"))
      {:ok, _f2, mod2} = compile_cached(nil, "7 * 6", elixir_ast!("7 * 6"))
      assert mod1 == mod2
    end

    @tag capture_log: true
    test "falls back to an interpreted closure when the pool is full" do
      start_supervised!({NativeCompiler, native_module_limit: 1})
      {:ok, _f1, mod1} = compile_cached(nil, "1 + 1", elixir_ast!("1 + 1"))
      assert is_atom(mod1) and mod1 != nil

      {:ok, f2, mod2} = compile_cached(nil, "2 + 2", elixir_ast!("2 + 2"))
      assert mod2 == nil
      assert Function.info(f2)[:module] == :erl_eval
      assert f2.(%{}) == 4
    end

    test "warns once (per server) when the pool fills" do
      start_supervised!({NativeCompiler, native_module_limit: 1})
      {:ok, _f1, _mod1} = compile_cached(nil, "1 + 1", elixir_ast!("1 + 1"))

      log =
        capture_log(fn ->
          {:ok, _, nil} = compile_cached(nil, "2 + 2", elixir_ast!("2 + 2"))
        end)

      assert log =~ "module pool is full"
      assert log =~ "native_module_limit: 1"

      refute capture_log(fn ->
               {:ok, _, nil} = compile_cached(nil, "3 + 3", elixir_ast!("3 + 3"))
             end) =~ "module pool is full"
    end

    test "the standalone compile/2 helper still works (Phase 1 unaffected)" do
      {:ok, fun} = NativeCompiler.compile("3 + 4")
      assert fun.(%{}) == 7

      assert_native(fun, "Elixir.ExCellerate.Compiled.E")
    end
  end

  describe "release/2 + grace-period purge" do
    alias ExCellerate.{Compiler, NativeCompiler, Parser}

    defp ast!(expr) do
      {:ok, ast} = Parser.parse(expr)
      Compiler.compile(ast)
    end

    test "releasing a module purges it after the grace period and frees its slot for reuse" do
      start_supervised!({NativeCompiler, native_module_limit: 1, native_purge_grace_ms: 20})

      {:ok, _fun_a, mod_a} = compile_cached(nil, "1 + 1", ast!("1 + 1"))
      assert %{free: 0, by_key: 1} = NativeCompiler.pool_stats()

      NativeCompiler.release(nil, "1 + 1")
      wait_until(fn -> match?(%{by_key: 0, free: 1}, NativeCompiler.pool_stats()) end)

      # The freed slot (same atom) is reused for the next expression.
      {:ok, fun_b, mod_b} = compile_cached(nil, "2 + 3", ast!("2 + 3"))
      assert mod_b == mod_a
      assert fun_b.(%{}) == 5
    end

    test "a fun whose slot was reused hands the scope to its on_stale" do
      start_supervised!({NativeCompiler, native_module_limit: 1, native_purge_grace_ms: 20})
      on_stale = fn scope, stale_mod -> {:stale, scope, stale_mod} end

      {:ok, held, mod_a} = NativeCompiler.compile_cached(nil, "a + 1", ast!("a + 1"), on_stale)
      assert held.(%{"a" => 1}) == 2

      NativeCompiler.release(nil, "a + 1")
      wait_until(fn -> NativeCompiler.pool_stats().free == 1 end)

      # Purged, slot not yet reused: the module is gone.
      assert held.(%{"a" => 1}) == {:stale, %{"a" => 1}, mod_a}

      # Slot reused by another expression: the generation no longer matches.
      {:ok, _other, ^mod_a} = compile_cached(nil, "a * 5", ast!("a * 5"))
      assert held.(%{"a" => 1}) == {:stale, %{"a" => 1}, mod_a}
    end

    test "a function captured just before release still evaluates during the grace window" do
      start_supervised!({NativeCompiler, native_module_limit: 4, native_purge_grace_ms: 1000})

      {:ok, fun, _mod} = compile_cached(nil, "10 * 2", ast!("10 * 2"))
      NativeCompiler.release(nil, "10 * 2")

      # Within the (long) grace window the captured fun is still valid.
      assert fun.(%{}) == 20
    end

    test "releasing an unknown or interpreted-fallback key is a no-op" do
      start_supervised!({NativeCompiler, native_module_limit: 4, native_purge_grace_ms: 20})

      assert :ok = NativeCompiler.release(nil, "never_compiled")
      # No crash; pool unchanged.
      assert %{by_key: 0} = NativeCompiler.pool_stats()
    end

    test "does not free a slot while its module's code is still executing" do
      start_supervised!({NativeCompiler, native_module_limit: 1, native_purge_grace_ms: 10})

      # The block(...) call must sit in NON-tail position (the `+ 1`) so the
      # generated eval frame stays on the running process's call stack while it
      # blocks. A bare "block(parent)" tail-calls out of eval, so its code is no
      # longer "in use" and soft_purge would succeed immediately.
      expr = "block(parent) + 1"
      {:ok, ast} = Parser.parse(expr)
      elixir_ast = Compiler.compile(ast, BlockReg)
      {:ok, fun, mod} = compile_cached(BlockReg, expr, elixir_ast)

      # Run the native fun in another process and wait until it is blocked
      # inside the module's code.
      parent = self()
      task = Task.async(fn -> fun.(%{"parent" => parent}) end)
      assert_receive {:blocked, runner}

      # Release while the call is still running. Once the purge has deleted the
      # module (its code becomes "old"), the same handler's soft_purge has seen
      # the code in use; pool_stats/0 is served after that handler, so the slot
      # must still be taken.
      NativeCompiler.release(BlockReg, expr)
      wait_until(fn -> :erlang.check_old_code(mod) end)
      assert NativeCompiler.pool_stats().free == 0

      # The in-flight call completes correctly despite the release.
      send(runner, :unblock)
      assert Task.await(task) == 1

      # Once the code is no longer running, a later purge cycle frees the slot.
      wait_until(fn -> NativeCompiler.pool_stats().free == 1 end)
    end
  end
end
