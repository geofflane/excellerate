# priv/bench/native_bench.exs
#
# Compares the interpreted (Code.eval_quoted) path against the native
# (Module.create) path on the warm path (fun.(scope)) and the cold path
# (parse + compile), with a hand-written Elixir baseline as the native floor.
#
# Run: mise exec -- mix run priv/bench/native_bench.exs

alias ExCellerate.{Compiler, NativeCompiler, Parser}

scope = %{
  "user" => %{"profile" => %{"address" => %{"zip" => "12345"}}},
  "a" => 15,
  "b" => 5
}

expressions = %{
  "arithmetic" => "1 + 2 * 3 / (4 - 1)",
  "nested_access" => "user.profile.address.zip",
  "function_calls" => "abs(-10) + round(1.5) + max(10, 20)",
  "ternary_logic" => "a > 10 && b < 20 ? 'valid' : 'invalid'"
}

# Hand-written native floor for each expression.
baselines = %{
  "arithmetic" => fn _ -> 1 + 2 * 3 / (4 - 1) end,
  "nested_access" => fn s -> s["user"]["profile"]["address"]["zip"] end,
  "function_calls" => fn _ -> abs(-10) + round(1.5) + max(10, 20) end,
  "ternary_logic" => fn s -> if s["a"] > 10 && s["b"] < 20, do: "valid", else: "invalid" end
}

interpreted_cold = fn expr ->
  {:ok, ast} = Parser.parse(expr)
  elixir_ast = Compiler.compile(ast)
  scope_var = Compiler.scope_var()
  fun_ast = {:fn, [], [{:->, [], [[scope_var], elixir_ast]}]}
  {fun, _} = Code.eval_quoted(fun_ast)
  fun
end

IO.puts("\n=== WARM PATH (fun.(scope), compiled once) ===")

Enum.each(expressions, fn {key, expr} ->
  interpreted = ExCellerate.compile!(expr)
  native = NativeCompiler.compile!(expr)
  baseline = baselines[key]

  IO.puts("\n--- #{key}: #{expr} ---")

  Benchee.run(
    %{
      "interpreted (eval_quoted)" => fn -> interpreted.(scope) end,
      "native (Module.create)" => fn -> native.(scope) end,
      "hand-written baseline" => fn -> baseline.(scope) end
    },
    time: 3,
    memory_time: 1,
    print: [configuration: false]
  )
end)

IO.puts("\n=== COLD PATH (parse + compile, no cache) ===")

Enum.each(expressions, fn {key, expr} ->
  IO.puts("\n--- #{key}: #{expr} ---")

  Benchee.run(
    %{
      "parse only" => fn -> Parser.parse(expr) end,
      "interpreted compile" => fn -> interpreted_cold.(expr) end,
      "native compile" => fn -> NativeCompiler.compile!(expr) end
    },
    time: 3,
    print: [configuration: false]
  )
end)
