# Native Compilation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Compile each expression into a real BEAM module (so evaluation runs compiled native code) instead of an interpreted `Code.eval_quoted` closure — measured behind a benchmark go/no-go gate, then integrated safely if worthwhile.

**Architecture:** Phase 1 adds a standalone `ExCellerate.NativeCompiler.compile/2` using `Module.create/3` plus benchmarks comparing interpreted vs native (warm + cold) against a hand-written baseline — no cache changes, zero risk. Phase 1 ends at a **gate**: only proceed if native is meaningfully faster net of compile cost. Phase 2 integrates compile-every into the cache with a bounded module-name slot pool (atom-exhaustion safe), grace-period soft-purge on eviction, and a config flag.

**Tech Stack:** Elixir (`~> 1.17`), `Module.create/3`, `:code` (purge/delete), ETS, ExUnit, Benchee. All `mix` commands run through `mise exec -- mix …`.

**Spec:** `docs/superpowers/specs/2026-06-01-native-compilation-design.md`

---

## File Structure

**Phase 1**
- Create `lib/excellerate/native_compiler.ex` — `ExCellerate.NativeCompiler`: pure compile-to-module helper (`compile/2`, `compile!/2`). One responsibility: turn an expression into a `&Mod.eval/1` capture backed by a real module.
- Create `test/native_compiler_test.exs` — parity with the interpreted path + proof the result is genuinely native (not `:erl_eval`).
- Create `priv/bench/native_bench.exs` — interpreted vs native, warm + cold, vs hand-written baseline; parse-only.

**Phase 2** (gated — see tasks 6+)
- Grow `lib/excellerate/native_compiler.ex` into a GenServer owning the slot pool + purge lifecycle.
- Modify `lib/excellerate/cache.ex` — store `mod_name` per entry; release modules on eviction.
- Modify `lib/excellerate.ex:465` `compile_to_function/2` — route to `NativeCompiler` when native compilation is enabled.
- Test files for slot allocation, purge, concurrency, fallback.

---

## Phase 1 — Measure (the go/no-go gate)

### Task 1: `ExCellerate.NativeCompiler.compile/2` (Module.create path)

**Files:**
- Create: `lib/excellerate/native_compiler.ex`
- Test: `test/native_compiler_test.exs`

- [ ] **Step 1: Write the failing test (parity + nativeness)**

```elixir
# test/native_compiler_test.exs
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
      assert info[:module] |> Atom.to_string() |> String.starts_with?("Elixir.ExCellerate.Compiled")
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mise exec -- mix test test/native_compiler_test.exs`
Expected: FAIL — `ExCellerate.NativeCompiler` is undefined.

- [ ] **Step 3: Write the minimal implementation**

```elixir
# lib/excellerate/native_compiler.ex
defmodule ExCellerate.NativeCompiler do
  @moduledoc false
  # Internal: compiles an expression into a real BEAM module so evaluation runs
  # compiled code rather than the :erl_eval interpreter that Code.eval_quoted
  # produces. Phase 1: standalone helper for benchmarking. No caching here.

  alias ExCellerate.{Compiler, Parser}

  @spec compile(String.t(), module() | nil) ::
          {:ok, (ExCellerate.scope() -> any())} | {:error, ExCellerate.Error.t()}
  def compile(expression, registry \\ nil) do
    case Parser.parse(expression) do
      {:ok, ast} ->
        try do
          {:ok, build_module_fun(ast, registry)}
        rescue
          e -> {:error, e}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec compile!(String.t(), module() | nil) :: (ExCellerate.scope() -> any())
  def compile!(expression, registry \\ nil) do
    case compile(expression, registry) do
      {:ok, fun} -> fun
      {:error, error} -> raise error
    end
  end

  defp build_module_fun(ast, registry) do
    elixir_ast = Compiler.compile(ast, registry)
    scope_var = Compiler.scope_var()
    mod_name = unique_module_name()

    body =
      quote do
        def eval(unquote(scope_var)) do
          # Mark the scope param used so scope-less expressions (e.g. "1 + 2")
          # do not emit an unused-variable warning at Module.create time. The
          # interpreted fn-wrapper path does not warn on unused args; match that.
          _ = unquote(scope_var)
          unquote(elixir_ast)
        end
      end

    Module.create(mod_name, body, Macro.Env.location(__ENV__))
    Function.capture(mod_name, :eval, 1)
  end

  defp unique_module_name do
    Module.concat(ExCellerate.Compiled, "E#{:erlang.unique_integer([:positive])}")
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mise exec -- mix test test/native_compiler_test.exs`
Expected: PASS (5 tests).

- [ ] **Step 5: Verify clean compile + format**

Run: `mise exec -- mix compile --warnings-as-errors && mise exec -- mix format`
Expected: clean compile, `native_compiler.ex` formatted.

- [ ] **Step 6: Commit**

```bash
git add lib/excellerate/native_compiler.ex test/native_compiler_test.exs
git commit -m "Add NativeCompiler.compile/2 (Module.create native path)"
```

### Task 2: Parity across the full expression corpus

**Files:**
- Test: `test/native_compiler_test.exs` (add a describe block)

- [ ] **Step 1: Write the failing test (corpus parity)**

```elixir
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
        {:ok, native} = ExCellerate.NativeCompiler.compile(unquote(expr))
        {:ok, interpreted} = ExCellerate.compile(unquote(expr))
        assert native.(unquote(Macro.escape(scope))) == interpreted.(unquote(Macro.escape(scope)))
      end
    end
  end
```

- [ ] **Step 2: Run test to verify it fails (or passes immediately — characterization)**

Run: `mise exec -- mix test test/native_compiler_test.exs`
Expected: PASS — this characterizes parity. If any case FAILS, the native path has a real codegen bug for that construct; fix `build_module_fun` before proceeding (do not edit the test to pass).

- [ ] **Step 3: Commit**

```bash
git add test/native_compiler_test.exs
git commit -m "Add NativeCompiler parity tests across expression corpus"
```

### Task 3: Benchmark — interpreted vs native (warm + cold) vs baseline

**Files:**
- Create: `priv/bench/native_bench.exs`

- [ ] **Step 1: Write the benchmark script**

```elixir
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
```

- [ ] **Step 2: Run the benchmark**

Run: `mise exec -- mix run priv/bench/native_bench.exs`
Expected: completes and prints warm + cold tables for all four expressions.

- [ ] **Step 3: Commit the benchmark**

```bash
git add priv/bench/native_bench.exs
git commit -m "Add native-vs-interpreted benchmark (warm, cold, baseline)"
```

### Task 4: GATE — record results and decide

**Not a code step — a decision checkpoint.**

- [ ] **Step 1: Record the numbers.** Paste the warm-path (interpreted vs native vs baseline) and cold-path (interpreted compile vs native compile) results into the design spec under a new "## Benchmark Results (Phase 1)" section, with the date.

- [ ] **Step 2: Compute break-even.** `break_even_evals ≈ (native_compile_cost − interpreted_compile_cost) / (interpreted_warm_per_call − native_warm_per_call)`. This is how many repeat evaluations of one expression it takes for native to pay back its higher compile cost.

- [ ] **Step 3: Decide and write the decision in the spec.**
  - **Proceed to Phase 2** if native warm is meaningfully faster (rule of thumb: ≥ ~2× and approaching the hand-written baseline) **and** break-even is small relative to expected repeat-eval counts for cached workloads.
  - **Stop** otherwise: keep the interpreted path. Optionally keep `NativeCompiler` + benchmark for the record, or revert. Either way, **do not implement Phase 2.**

- [ ] **Step 4: Commit the decision.**

```bash
git add docs/superpowers/specs/2026-06-01-native-compilation-design.md
git commit -m "Record Phase 1 benchmark results and go/no-go decision"
```

---

## Phase 2 — Integrate (ONLY if Task 4 says proceed)

> Phase 2 is gated. The tasks below are the planned breakdown; firm up the exact
> code (especially the grace-purge timing and slot-pool numbers) using the Phase 1
> numbers before executing. Every task is TDD: failing test → minimal code → green
> → commit. Verification after each task: `mise exec -- mix compile --warnings-as-errors && mise exec -- mix format --check-formatted && mise exec -- mix test`.

### Task 5: Slot allocator as pure state (no VM side effects yet)

**Files:**
- Modify: `lib/excellerate/native_compiler.ex` — add a `Slots` sub-module / struct.
- Test: `test/native_compiler/slots_test.exs`

**Responsibility:** a pure data structure managing module-name atoms: a free-list, a high-water counter, and a global cap. No `Module.create`/`:code` calls — just allocation bookkeeping, unit-testable in isolation.

- [ ] **Step 1: Failing tests** for: `new(cap)`; `alloc/1` returns `{:ok, name, state}` minting `ExCellerate.Compiled.S0`, `S1`, … in order; `alloc/1` reuses a freed name before minting a new one; `alloc/1` returns `{:full, state}` when free-list empty and at cap; `free/2` returns a name to the free-list. Assert atom names are stable/reused (a freed-then-realloc'd slot yields the **same** atom).
- [ ] **Step 2–4:** Implement the struct + `new/1`, `alloc/1`, `free/2`; run red→green.
- [ ] **Step 5: Commit** `"Add native module slot allocator (pure state)"`.

### Task 6: GenServer lifecycle — compile + dedup

**Files:**
- Modify: `lib/excellerate/native_compiler.ex` — `use GenServer`; `start_link/1`, `child_spec/1`, `init/1` (holds `%{slots: Slots.t(), by_key: %{{registry, expr} => mod_name}}`).
- Add public API: `compile_cached(registry, expr, elixir_ast) → {:ok, fun, mod_name} | {:ok, interpreted_fun, nil}` (serialized `call`).
- Test: `test/native_compiler_test.exs` (server describe block; start the server in setup).

**Responsibility:** serialize `Module.create` + slot allocation through one process; dedup so the same `{registry, expr}` reuses its module; fall back to an interpreted closure (current `Code.eval_quoted` wrapper) when slots are full.

- [ ] **Step 1: Failing tests** for: compiling returns an `:external` fun on a `ExCellerate.Compiled.S*` module; compiling the same `{registry, expr}` twice returns the **same** mod_name (dedup, one module); when the pool is full (`new(0)` or tiny cap) it returns `{:ok, interpreted_fun, nil}` whose `Function.info[:module] == :erl_eval`.
- [ ] **Step 2–4:** Implement; red→green. Extract the interpreted-closure builder so both `NativeCompiler` (fallback) and the existing `compile_to_function/2` share it (DRY).
- [ ] **Step 5: Commit** `"Add NativeCompiler GenServer: serialized compile + dedup + fallback"`.

### Task 7: Release + grace-period soft-purge

**Files:**
- Modify: `lib/excellerate/native_compiler.ex` — `release(mod_name)` (cast); pending-purge queue; timer-driven `:purge` handling using `:code.delete/1` + `:code.soft_purge/1`; requeue on in-use; free slot only after successful purge.
- Test: `test/native_compiler_test.exs`.

**Responsibility:** reclaim slots without ever killing an in-flight evaluation.

- [ ] **Step 1: Failing tests** for: after `release/1` + grace elapse, the module is purged (`:code.is_loaded(mod) == false`) and its slot is reused on the next `compile_cached`; a module whose captured fun is actively running is **not** purged until the call returns (drive with a slow custom registry function in a spawned process; assert no crash and correct result).
- [ ] **Step 2–4:** Implement the queue + soft-purge protocol; red→green. Use a configurable grace delay (start with the value chosen from Phase 1 timings; default conservative).
- [ ] **Step 5: Commit** `"Add grace-period soft-purge and slot reclamation"`.

### Task 8: Cache integration + config flag + supervision

**Files:**
- Modify: `lib/excellerate/cache.ex` — ETS tuple → `{full_key, value, last_accessed, mod_name}`; `get/2`, `put/4` (accept `mod_name`); `evict_lru/2` calls `NativeCompiler.release/1` for non-nil `mod_name`; bump `@ts_pos` consumers accordingly.
- Modify: `lib/excellerate.ex:465` `compile_to_function/2` — when native enabled, call `NativeCompiler.compile_cached/3` and pass `mod_name` to `Cache.put/4`; else current path with `mod_name = nil`.
- Modify: config readers — add `native_compilation` (Application env + per-registry `__excellerate_config__/1`), mirroring `cache_enabled`.
- Modify: `lib/excellerate/registry.ex` — thread a `:native_compilation` option through `__using__`.
- Test: `test/native_compilation_integration_test.exs`.

- [ ] **Step 1: Failing tests** for: with native enabled and `Cache` + `NativeCompiler` started, `ExCellerate.eval!/2` returns correct results and the cached value is an `:external` fun; eviction past the limit releases the evicted module (slot reused, module purged); `native_compilation: false` → interpreted path (`:erl_eval`); `NativeCompiler` not started → interpreted fallback (no crash).
- [ ] **Step 2–4:** Implement; red→green. Keep the public `compile/2` contract (`{:ok, fun}`) unchanged.
- [ ] **Step 5: Commit** `"Integrate native compilation into the cache behind a config flag"`.

### Task 9: Concurrency + atom-bound safety tests

**Files:**
- Test: `test/native_compilation_integration_test.exs` (add describe blocks).

- [ ] **Step 1: Failing/holding tests** for:
  - **Churn under tiny cache limit:** spawn ~50 tasks each evaluating a mix of shared and distinct expressions against a registry with `cache_limit: 5` (forces constant eviction/purge) → all return correct results, no process crashes.
  - **Atom bound:** record `:erlang.system_info(:atom_count)`, evaluate several thousand distinct expressions with `native_module_limit` small, assert atom_count growth is bounded by roughly the cap (proves slot reuse, not per-expression atom leak).
- [ ] **Step 2–4:** Run; fix any races surfaced (these tests are the real validation of the grace-purge + serialization design).
- [ ] **Step 5: Commit** `"Add concurrency and atom-bound safety tests for native compilation"`.

### Task 10: Default, docs, changelog

**Files:**
- Modify: config default for `native_compilation` (per Phase 1 results — opt-in vs on-by-default).
- Modify: `lib/excellerate.ex` moduledoc + `README.md` — if native is enabled by default, the performance description can now accurately mention compiled-module evaluation; otherwise document `native_compilation` as an opt-in with its tradeoffs (atom pool, purge).
- Modify: `CHANGELOG.md` if present.

- [ ] **Step 1:** Update config default + docs to match the shipped behavior. No new code claims that aren't true of the default.
- [ ] **Step 2: Verify** `mise exec -- mix compile --warnings-as-errors && mise exec -- mix format --check-formatted && mise exec -- mix test`.
- [ ] **Step 3: Commit** `"Set native-compilation default and update docs"`.

---

## Self-Review

**Spec coverage:** Module.create mechanism → Task 1. Compile-every policy → Tasks 6/8. Bounded atom slot pool → Tasks 5/6, validated Task 9. Grace-period soft-purge on eviction → Tasks 7/8. Config flag + per-registry override + supervision/fallback → Task 8. Benchmark plan + go/no-go gate → Tasks 3/4. Parity + concurrency + atom-bound + fallback tests → Tasks 2/6/7/8/9. All spec sections map to tasks.

**Placeholder scan:** Phase 1 contains complete code (impl, tests, bench). Phase 2 tasks intentionally specify files + responsibilities + test intent + key code sketches rather than full code, because they are gated on the Phase 1 result and the grace-delay/pool numbers are derived from Phase 1 timings — this is a deliberate, flagged deferral, not a hidden TODO. Execute Phase 2 task-by-task, writing the concrete code/tests at that point.

**Type consistency:** `compile/2`/`compile!/2` (Phase 1) return `{:ok, fun}` / `fun`; `compile_cached/3` (Phase 2) returns `{:ok, fun, mod_name}`; `release/1` takes a `mod_name`; `Slots` API is `new/1`, `alloc/1` (`{:ok, name, state}` | `{:full, state}`), `free/2`; cache value contract `&Mod.eval/1` matches the public `compile/2` 1-arity contract throughout.
