# bench/caching_bench.exs
#
# Benchmarks comparing eval (parse+compile+execute every call),
# cached eval (compile once, execute from cache), and pre-compiled
# function invocation (no dispatch overhead at all).

ExCellerate.Cache.start_link()

expressions = %{
  "simple_arithmetic" => "1 + 2 * 3 / (4 - 1)",
  "nested_access" => "user.profile.address.zip",
  "function_calls" => "abs(-10) + round(1.5) + max(10, 20)",
  "ternary_and_logic" => "a > 10 && b < 20 ? 'valid' : 'invalid'"
}

scope = %{
  "user" => %{"profile" => %{"address" => %{"zip" => "12345"}}},
  "a" => 15,
  "b" => 5
}

# Pre-compile all expressions into reusable functions.
# Benchee passes the input value to each function, so we build inputs
# as {expr, pre_compiled_fun} tuples.
inputs =
  Map.new(expressions, fn {key, expr} ->
    {key, {expr, ExCellerate.compile!(expr)}}
  end)

Benchee.run(
  %{
    "eval! (cached)" => fn {expr, _fun} ->
      ExCellerate.eval!(expr, scope)
    end,
    "pre-compiled fun" => fn {_expr, fun} ->
      fun.(scope)
    end,
    "parse + compile (no cache)" => fn {expr, _fun} ->
      {:ok, ast} = ExCellerate.Parser.parse(expr)
      elixir_ast = ExCellerate.Compiler.compile(ast)
      scope_var = ExCellerate.Compiler.scope_var()
      fun_ast = {:fn, [], [{:->, [], [[scope_var], elixir_ast]}]}
      {fun, _} = Code.eval_quoted(fun_ast)
      fun.(scope)
    end
  },
  inputs: inputs,
  time: 5,
  memory_time: 2
)
