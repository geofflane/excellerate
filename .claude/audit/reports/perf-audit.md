# ExCellerate Performance Audit

Scope: parse / compile / eval hot path, caching, function dispatch, allocations,
benchmark coverage. No DB concerns apply (pure library).

Health score: **58 / 100** — see justification at the end.

Files: `lib/excellerate.ex`, `lib/excellerate/compiler.ex`, `lib/excellerate/cache.ex`,
`lib/excellerate/registry.ex`, `lib/excellerate/functions.ex`,
`lib/excellerate/parser.ex`, `priv/bench/caching_bench.exs`.

---

## Findings, ranked by impact

### 1. `Code.eval_quoted/3` on every cold compile — the dominant cost (CRITICAL)

`ExCellerate.compile_to_function/2` (`lib/excellerate.ex:446-465`) builds an `fn`
AST and runs it through `Code.eval_quoted(fun_ast, [], __ENV__)`.

`Code.eval_quoted` is the **interpreter** path. It does not produce a fast,
JIT-compiled function — it returns a closure that the Erlang `:erl_eval`
interpreter walks **every time the function is invoked**. Two compounding problems:

- **Cold compile is very expensive.** `Code.eval_quoted` invokes the full
  expand/eval machinery for the whole expression tree on each first-time
  expression. This is the bulk of the "parse + compile (no cache)" benchmark
  time, and it is what the cache exists to avoid.
- **Even the cached/“compiled” function is interpreted, not native.** Because
  the closure produced by `Code.eval_quoted` is an `:erl_eval` closure, every
  `fun.(scope)` re-interprets the AST. The library's headline claim — "compiles
  into native Elixir AST for near-native performance" (`excellerate.ex:6`) — is
  not actually realized. The IR is turned into Elixir AST, but that AST is never
  compiled to BEAM bytecode; it is interpreted.

Impact: this is the single largest perf issue and it affects **both** the cold
path (compile latency) and the warm path (every evaluation of a cached
expression runs the interpreter, typically 1–2 orders of magnitude slower than a
real compiled function).

Optimization options (in rough order of payoff/effort):
- Replace `Code.eval_quoted` with real module generation: emit the AST as a
  function inside a uniquely-named module via `Module.create/3` (or
  `defmodule` + `Code.compile_quoted`) and cache the resulting `&Mod.eval/1`
  capture. This gives a genuinely compiled, JIT-able function. Beware: each
  distinct expression creates a module; you must reuse via the cache (which
  already exists) and consider purging on eviction (`:code.purge/1`).
- If module-per-expression is undesirable, at minimum measure
  `Code.eval_quoted` vs a compiled module — the benchmark currently hides this
  because "pre-compiled fun" is *also* an `:erl_eval` closure, so it measures
  interpreter-vs-interpreter, not interpreter-vs-native.

### 2. Default-function dispatch does a linear scan (HIGH, cold path)

When `registry == nil` (the default, used by `ExCellerate.eval/2` with no
registry), `Compiler.resolve_module_at_compile_time/2` calls
`ExCellerate.Functions.get_default_function/1` (`functions.ex:78-80`), which is:

```elixir
Enum.find(@default_functions, fn module -> module.name() == name end)
```

This is an **O(n) linear scan over ~55 modules, calling `module.name()`
(a remote function call) on each**, performed once per function node per cold
compile. For an expression with several function calls this is repeated per
call site. A custom `Registry` avoids this (it generates `resolve_function/1`
pattern-match clauses at compile time — `registry.ex:91-96`), but the *default*
path — the most common one — does not.

Fix: build a compile-time map `%{name => module}` in `ExCellerate.Functions`
(module attribute) and do a single `Map.fetch/2`, or generate
`get_default_function/1` pattern-match clauses the same way the Registry does.
This is purely a cold-compile cost (resolution happens at compile time, not per
eval), but it inflates first-compile latency and is trivially fixable.

### 3. Runtime dispatch guard runs `Code.ensure_loaded?` + `function_exported?` on EVERY call (HIGH, warm path) — the `compiler.ex:33` TODO

`Compiler.invoke_module/2` (`compiler.ex:32-59`) is invoked from generated AST on
every function call at runtime. On each invocation it runs:

- `Code.ensure_loaded?(module)` — a call into the code server,
- `function_exported?(module, :call, 1)`,
- then in `validate_module_arity!`, another `function_exported?(module, :arity, 0)`,
- then `module.arity()` and `length(args)` to re-validate arity.

The `# TODO: Is there a way to do this once instead of every call?` at
`compiler.ex:33` is correct to flag this. **All of this is redundant at runtime**:
the module was already resolved and arity-validated at compile time
(`compile_named_call/3` → `validate_arity!/3`, `compiler.ex:197-217`). For a
known, compile-time-resolved module, the generated AST could call
`module.call(args)` directly (wrapped in the rescue for error formatting) with
no `ensure_loaded?`/`function_exported?`/arity re-check.

Impact: every function call in every evaluation pays for two-to-three
`function_exported?` lookups plus a code-server round trip. For expressions
heavy in function calls (the common spreadsheet case), this is a large per-call
tax on the warm path.

Fix: split the generated dispatch into two paths. For compile-time-resolved
module calls (`compile_named_call`), emit a lean `module.call(args)` wrapped only
in the error-translation `try/rescue` — drop all the defensive checks. Keep the
fully-guarded `dispatch_call/2` only for the genuinely dynamic target case
(`to_elixir_ast({:call, target, args})` non-name branch, `compiler.ex:475-484`).

### 4. Cache: per-`put` O(n) count + O(n log n) eviction scan (MEDIUM)

`Cache.put/3` (`cache.ex:70-83`) runs on every cold insert:

- `count_for_registry/1` → `:ets.select_count` scanning the **whole table**
  filtered by registry, every put.
- When over limit, `evict_lru/2` (`cache.ex:142-150`) does `:ets.match` to pull
  **all** entries for the registry into a list, `Enum.sort_by` them, take N, and
  delete. That is O(n log n) over the entire registry partition on every insert
  once the table is full.

For a workload that thrashes the cache (many distinct expressions, e.g.
user-supplied formulas), this makes each miss progressively more expensive.
Counting on every put even when well under the limit is wasted work.

Notes / fixes:
- The LRU "touch" on every `get` hit (`:ets.update_element`, `cache.ex:58`) turns
  every read into a write, defeating `read_concurrency` and serializing hot
  reads. Consider a sampling/segmented LRU or dropping strict LRU for a cheaper
  policy (e.g. counter-based or a sharded approach).
- Track count via `:ets.info(table, :size)` or an atomic counter instead of
  `select_count` per put (note: size is whole-table, not per-registry — a
  per-registry atomics counter would be needed to keep partitioning).
- Eviction allocates a full list of the partition every time; a `:ets.select`
  with a bounded match or an ordered_set keyed by timestamp would avoid the
  full sort.

### 5. Cache correctness: compiled-fn capture survives, but module-generation fix needs purge accounting (MEDIUM)

Currently the cached value is an `:erl_eval` closure, so there is no module
leak today. **However**, if you adopt the Finding #1 fix (real module
generation), each cached expression creates a BEAM module. Eviction
(`evict_lru`) only deletes the ETS row — it would need to `:code.purge/1` /
`:code.delete/1` the generated module, or you will leak code memory unboundedly
as expressions churn. Flagging now because the obvious perf fix introduces a
correctness/leak risk that the current eviction path does not handle.

Also: `enabled?/1` and `get_limit/1` (`cache.ex:152-176`) call
`Code.ensure_loaded?(registry)` + `function_exported?` on **every get and put**.
For the `nil` registry (default) this is skipped, but any custom-registry
workload pays a code-server round trip per cache operation. Cache the config
once (e.g. read it into the generated registry at compile time, or memoize in
`:persistent_term`).

### 6. Per-call allocations on the hot path (MEDIUM)

- **Argument list rebuild per call.** `compile_named_call/3` emits
  `actual_args = [arg1, arg2, ...]` then `dispatch_call(module, actual_args)`
  (`compiler.ex:213-216`). The arg list is freshly allocated every call, then
  `invoke_module` re-measures it with `length(args)`. With the Finding #3 fix
  (direct `module.call([...])`), the list is still built but the `length/1`
  re-walk goes away.
- **`flat_spread/2` does `List.flatten/1` then `Enum.map/2`** (`compiler.ex:395-399`)
  — two full passes plus deep flatten allocation on every nested-spread
  evaluation. Could be a single `Enum.flat_map` (still a fix re-call, but one
  pass) where shape allows.
- **`merge_item_scope` does `Map.merge/2` per spread item** (`compiler.ex:142-144`)
  — allocates a new scope map for every element of a computed spread. Expected
  for correctness (item keys shadow outer), but it is O(scope size) per item;
  large outer scopes × large lists multiply. Worth documenting / considering a
  layered lookup instead of a merged map.
- **Access path `map_get`/`fetch_from_scope`** (`compiler.ex:103-134`) do a
  string lookup, then on miss `String.to_existing_atom/1` inside a `try/rescue`.
  The `try/rescue` for the atom-fallback is on the hot path for every atom-keyed
  or missing-key access. `String.to_existing_atom` can be guarded more cheaply,
  but the bigger point is this runs on every variable/field access.

### 7. Benchmark coverage gaps (MEDIUM — blocks measuring everything above)

`priv/bench/caching_bench.exs` is the **only** benchmark and it has structural
gaps that hide the most important issues:

- **"pre-compiled fun" is itself a `Code.eval_quoted` closure** (it reuses
  `ExCellerate.compile!`, line 27, which goes through the same interpreter
  path). So the bench compares interpreter-vs-interpreter; it does **not**
  measure native compilation, and it cannot reveal Finding #1. There is no
  baseline of a hand-written Elixir function doing the same computation.
- **No parse-only benchmark.** Parser speed (`Parser.parse/1`) is never isolated,
  so parse cost vs compile cost cannot be attributed.
- **No function-dispatch microbenchmark.** The per-call `function_exported?` /
  `ensure_loaded?` tax (Finding #3) and the default linear scan (Finding #2) are
  unmeasured.
- **No cache-thrash / eviction benchmark.** The O(n log n) eviction and
  per-put `select_count` (Finding #4) only show up under churn with a full
  cache; the current bench uses 4 fixed expressions that always hit, so the
  eviction path is never exercised.
- **No spread / computed-spread / `let` / `filter` / `table` benchmarks.** These
  allocate the most (Finding #6) and are entirely unmeasured.
- **No memory comparison across registry vs default** path.

Add benchmarks for: parse-only; cold compile (cache cleared each iter); warm
eval vs a native hand-written equivalent; function-heavy expressions; cache
under churn (more distinct expressions than the limit); and spread/computed-
spread workloads with `memory_time`.

---

## Performance health score: 58 / 100

Justification:
- The core architecture (IR → AST, ETS cache keyed by `{registry, expr}`,
  compile-time resolution + arity check, precedence-split parser) is sound and
  the cache does prevent re-parsing on the warm path — this earns a solid base.
- **−25** for Finding #1: the central performance promise ("compiles to native
  Elixir AST for near-native performance") is not met — `Code.eval_quoted`
  yields an interpreted closure, so every evaluation runs the `:erl_eval`
  interpreter. This caps achievable throughput well below the claim and inflates
  cold-compile latency.
- **−8** for Finding #3: redundant `ensure_loaded?`/`function_exported?`/arity
  re-checks on every function call at runtime (the acknowledged `compiler.ex:33`
  TODO).
- **−4** for Finding #2: O(n) linear scan with remote `name/0` calls on the
  default (most common) resolution path.
- **−3** for Finding #4: per-put full-partition count + O(n log n) eviction, and
  read-path writes defeating `read_concurrency`.
- **−2** for Finding #7: the only benchmark can't measure the biggest issues and
  several hot paths (spread, dispatch, eviction, parse) are unbenchmarked.

Highest-leverage next step: replace `Code.eval_quoted` with genuine module
compilation (and handle module purging on cache eviction), then add a benchmark
that baselines against a hand-written native function so the win is measurable.
