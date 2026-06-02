# Native Compilation Design

**Date:** 2026-06-01
**Status:** Approved (design) — pending implementation plan
**Owner:** Geoff Lane

## Problem

`ExCellerate.compile/2` turns each expression into Elixir AST, then runs it
through `Code.eval_quoted/3` (`lib/excellerate.ex:475`). `Code.eval_quoted`
returns an **interpreted `:erl_eval` closure**: the AST is walked by the Erlang
interpreter on *every* invocation, never compiled to BEAM bytecode. The cached
"compiled" function is therefore interpreted, not native — so the library's
former headline claim of "near-native performance" was inaccurate (the docs have
since been corrected). This caps warm-path throughput well below a real compiled
function and makes cold compilation more expensive than necessary.

## Goal

Evaluate whether compiling each expression into a genuine BEAM module (so
evaluation runs compiled native code) is worth the added machinery, and if so,
ship it safely — without reintroducing the atom-exhaustion DoS class that the
resource-limit work just hardened against.

**The benchmark is the go/no-go gate.** If native compilation is not meaningfully
faster on the warm path (net of higher cold-compile cost), "keep the interpreted
path" is an acceptable and expected outcome.

## Non-Goals

- Dropping the redundant per-call dispatch guards in `Compiler.invoke_module/2`
  (perf finding #3 / the `compiler.ex:33` TODO). That is an orthogonal short-term
  item that speeds up **both** the interpreted and native paths. It is held
  constant in the benchmark to isolate the compile-vs-interpret effect.
- Changing the public API. `compile/2` continues to return `{:ok, fun}` where
  `fun` is a 1-arity function taking a scope map.
- Cache key/LRU policy redesign (perf finding #4). Out of scope here.

## Key Decisions

1. **Compilation mechanism:** `Module.create/3` (not `Code.compile_quoted/2`).
   Cleaner API for "a module with one function." We build a one-function module
   body and create a real loaded module:

   ```elixir
   body = quote do: (def eval(unquote(scope_var)), do: unquote(elixir_ast))
   Module.create(mod_name, body, Macro.Env.location(__ENV__))
   # cache stores  &mod_name.eval/1  — same 1-arity contract callers already use
   ```

   `scope_var` is the existing `Compiler.scope_var()`
   (`Macro.var(:scope, ExCellerate.Compiler)`); param and body share context, so
   the same hygiene mechanism the current `fn` wrapper relies on applies.

2. **Compilation policy:** compile **every** distinct expression (chosen over
   compile-on-repeat). Simplest warm path. Requires a bounded module-name slot
   pool (below) because module names are atoms and atoms are never
   garbage-collected — compiling unbounded distinct untrusted expressions would
   otherwise leak atoms and re-create an exhaustion DoS.

3. **Purge on eviction:** required, via a grace-period / soft-purge protocol
   (below) so eviction never crashes an in-flight evaluation.

## Architecture

### Phase 1 — Measure (standalone, zero risk to existing behavior)

Add a native-compile path and benchmarks. **No cache changes.** Goal: decide
whether native is worth Phase 2.

- A function that compiles an expression to a native `&Mod.eval/1` (simple
  deterministic/counter naming is fine here — the benchmark uses a small fixed
  set of expressions, so atom growth is not a concern at this stage).
- Benchmarks (see Testing & Benchmark Plan).
- **Go/no-go gate:** native warm-path meaningfully faster *and* cold-compile cost
  amortizes within a reasonable number of repeat evals (break-even N). If not,
  stop — keep the interpreted path, revert the spike.

### Phase 2 — Integrate (only if Phase 1 says yes)

Wire compile-every into the cache with full safety machinery.

#### `ExCellerate.NativeCompiler` (new GenServer)

Owns all native-code lifecycle, serialized through one process (`Module.create`,
`:code.purge`, `:code.delete` are global VM operations; serializing removes
creation/purge races).

- `compile(registry, expr, elixir_ast) → {:ok, fun, mod_name} | {:ok, interpreted_fun, nil}`
  — allocate a slot, `Module.create` into it, return `&Mod.eval/1`. **Dedupes:**
  if a slot already exists for `{registry, expr}`, return it (handles two callers
  compiling the same new expression concurrently).
- `release(mod_name)` — called on cache eviction; queues the module for purge and
  eventually frees the slot.
- If not started (like `Cache` today), native compilation is skipped →
  interpreted fallback. Joins the supervision tree next to `Cache`.

#### Slot allocator (bounds atoms)

- Module names from a fixed namespace: `ExCellerate.Compiled.S0`, `S1`, …, minted
  lazily up to a global cap (`config :excellerate, native_module_limit: 4096`).
- A free-list holds released slot atoms. Allocation reuses a freed atom (purge old
  module, recreate under the same name). **Atom count is bounded by the
  high-water mark ≤ the cap, then reused indefinitely.**
- If the free-list is empty **and** at the cap → **graceful fallback**: return an
  interpreted closure instead of a module. The atom cap can never be exceeded;
  under extreme pressure the library degrades to today's behavior rather than
  crashing.

#### Safe purge — grace-period / lazy purge

Hazard: a caller fetches `&Mod.eval/1` from the cache, the entry is evicted, and
the module is purged before the caller invokes it → crash.

Mitigation: released modules go to a pending-purge queue and are `:code.delete` +
**`:code.soft_purge`**'d after a short grace delay. `soft_purge` refuses to purge
while any process still runs the old code (requeue if so), so a live evaluation is
never killed; the microsecond eval window closes long before the grace delay
elapses. The slot atom returns to the free-list only after a successful purge.

#### Cache integration

- ETS tuple grows to `{full_key, value, last_accessed, mod_name}` (`mod_name` is
  `nil` for interpreted fallback).
- On a cache miss, `compile_to_function` asks `NativeCompiler` to compile and
  stores `&Mod.eval/1` plus the `mod_name`.
- On eviction (`evict_lru`), entries with a non-`nil` `mod_name` route a
  `release/1` to the GenServer.
- Per-registry cache limits stay as-is. Live native modules ≤ global atom cap; the
  remainder fall back to interpreted — coherent.

#### Config

- `config :excellerate, native_compilation: true | false` (default decided by
  Phase-1 results — likely opt-in initially).
- Per-registry override via `__excellerate_config__/1`, like the existing
  `cache_enabled` / `cache_limit` settings.
- When disabled → current interpreted path, unchanged.

## Data Flow (Phase 2, native enabled)

```
eval/compile(expr, registry)
  └─ Cache.get(registry, expr)
       ├─ hit  → {:ok, &Mod.eval/1}  → fun.(scope)
       └─ miss → Parser.parse → Compiler.compile (depth guard) → elixir_ast
                 → NativeCompiler.compile(registry, expr, elixir_ast)
                      ├─ slot available → Module.create → {:ok, &Mod.eval/1, mod_name}
                      └─ at cap         → {:ok, interpreted_fun, nil}
                 → Cache.put(... value, mod_name)
                      └─ over limit → evict_lru → NativeCompiler.release(mod_name)
                                        → queue → (grace) :code.delete + soft_purge
                                                  → free slot atom
```

## Error Handling

- Compile failures (parser/depth/compiler errors) behave exactly as today —
  `{:error, %ExCellerate.Error{}}`; no module is created.
- `Module.create` failure → fall back to interpreted closure for that expression
  (do not crash the caller); log once.
- `NativeCompiler` not started / `native_compilation: false` → interpreted path.
- `soft_purge` blocked (code in use) → requeue; slot not yet reclaimed (bounded by
  the cap + graceful fallback).

## Testing & Benchmark Plan

### Benchmarks (also closes perf finding #7)

The current `priv/bench/caching_bench.exs` compares interpreter-vs-interpreter
(the "pre-compiled fun" is itself a `Code.eval_quoted` closure). Add:

- parse-only
- cold-compile (cache cleared per iter): interpreted **vs** native
- warm-eval: interpreted closure **vs** native module **vs** hand-written native
  baseline
- a function-heavy expression
- (Phase 2) cache-churn with more distinct expressions than the limit, with
  `memory_time`

### Tests

- **Parity** (Phase 1 + 2): native-compiled eval returns identical results to
  interpreted across the existing expression corpus.
- **Slot exhaustion** → interpreted fallback, still correct.
- **Eviction releases modules:** churn past the limit; assert evicted modules are
  purged, slots reused, and `:erlang.system_info(:atom_count)` stays bounded
  across many distinct expressions.
- **Concurrency:** many processes evaluating overlapping + distinct expressions
  under a tiny cache limit (forces eviction/purge churn) → no crashes, correct
  results (exercises the eval-during-purge race).
- **Config off** → interpreted path; **Cache/NativeCompiler not started** →
  interpreted fallback.

## Risks & Open Questions

- **Complexity vs payoff:** Phase 2 is the most complex code in the project. If
  Phase 1's numbers are only marginally better, keeping the interpreted path is a
  legitimate outcome.
- **Grace-period tuning:** the purge delay trades a small amount of delayed memory
  reclamation for crash-safety. Default delay TBD during implementation (start
  conservative, e.g. a few hundred ms or "next eviction cycle").
- **Default on/off:** decided by Phase-1 benchmark results.

## Benchmark Results (Phase 1) — 2026-06-01

Run: `mise exec -- mix run priv/bench/native_bench.exs` (Benchee, time 3s, mem 1s).

### Warm path — per-call `fun.(scope)` (lower is better)

| Expression | interpreted | native | hand-written | native speedup | mem (interp → native) |
|------------|------------:|-------:|-------------:|---------------:|----------------------:|
| arithmetic | 231 ns | 26 ns | 4.1 ns | **8.7×** | 944 B → 0 B |
| function_calls | 893 ns | 209 ns | 4.1 ns | **4.3×** | 3,976 B → 72 B |
| nested_access | 9,827 ns | 85 ns | 53 ns | **116×** | 40,032 B → 24 B |
| ternary_logic | 1,501 ns | 54 ns | 40 ns | **27.8×** | 6,240 B → 48 B |

Native is 1.35×–6.5× of the hand-written floor; interpreted is 37×–218× slower
than the floor. Native also slashes per-eval allocation (interpreted nested
access allocates ~40 KB **per call**).

### Cold path — compile cost (lower is better)

| Expression | parse only | interpreted compile | native compile | extra cost (native − interp) |
|------------|-----------:|--------------------:|---------------:|-----------------------------:|
| arithmetic | 3.4 µs | 8.4 µs | 2,339 µs | ~2.33 ms |
| function_calls | 6.3 µs | 15.7 µs | 3,493 µs | ~3.48 ms |
| nested_access | 1.5 µs | 75 µs | 6,453 µs | ~6.38 ms |
| ternary_logic | 6.0 µs | 35 µs | 5,998 µs | ~5.96 ms |

Native compilation (`Module.create` → full BEAM compile) costs **~2.3–6.5 ms**
vs **~8–75 µs** interpreted — roughly 100–700× more expensive, once per
expression.

### Break-even (repeat evals of the *same* expression to amortize native's extra compile cost)

`break_even ≈ (native_compile − interp_compile) / (interp_warm − native_warm)`

| Expression | break-even (evals) |
|------------|-------------------:|
| nested_access | ~655 |
| ternary_logic | ~4,119 |
| function_calls | ~5,085 |
| arithmetic | ~11,385 |

### Reading

- **Warm-path win is large and real** (4×–116× faster, far less memory) — for
  expressions evaluated many times, native is clearly better.
- **Cold cost is heavy** (multi-ms per expression) — break-even is hundreds to
  ~11k repeat evaluations. For expressions evaluated only a handful of times,
  native is **strictly worse** (the compile cost dominates and adds multi-ms
  first-eval latency).
- **Implication for policy:** the approved "compile-every-expression" policy
  makes *every* distinct expression pay the multi-ms cost, only paying off for
  very hot expressions. The data argues for revisiting toward
  **compile-on-repeat** (compile only after an expression proves hot), so the
  warm-path win is captured only where it amortizes and one-shot/rare expressions
  keep the cheap interpreted path.

### Decision (2026-06-01): PROCEED to Phase 2 — compile-every (as originally approved)

Proceed with **compile-every-expression** as designed. Rationale (from the
consumer's workload): every expression is evaluated hundreds of times per game
(at minimum once per play), so each cached expression is far past break-even —
the compile-on-repeat hedge buys nothing here. Additionally, the per-eval
**allocation** drop is decisive on its own: interpreted allocates 944 B–40 KB
*per call* (40 KB for nested access), versus 0–72 B native. For a hot
per-play evaluation loop that is a major reduction in GC pressure independent of
raw speed. The bounded module-name slot pool + grace-period soft-purge (Phase 2)
still bound atoms and memory. Phase 2 (Tasks 5–10) proceeds as written; the
grace-purge delay can be short since evals are sub- to low-microsecond.

## Correction (2026-06-02): `Module.create` interns ~1 atom per call

**A core atom-safety assumption above is WRONG.** Empirically verified during
Task 9: `Module.create/3` interns **one permanent atom per call, even when the
module name is reused** (3000 creates of a single reused name → +3000 atoms;
soft_purge vs hard purge makes no difference). The interpreted `Code.eval_quoted`
path, by contrast, leaks **zero** atoms.

Consequences — what the slot pool actually does:

- The slot pool **bounds live module CODE/memory** (`minted ≤ native_module_limit`,
  modules purged + names reused on eviction). That part is real and works.
- The slot pool does **NOT** bound the **atom table**. Each DISTINCT expression
  that is natively compiled costs ~1 permanent atom, churn or not. Under
  unbounded distinct input the atom table grows ~1/expr (slow: ~1M distinct
  expressions to exhaust the default table, irreversible).

Therefore the earlier claims that compile-every is "atom-exhaustion safe under
unbounded distinct untrusted input via the slot pool" are **false**. Native
compilation is safe against *code/memory* growth, not *atom* growth.

**Decision (2026-06-02): SHIP anyway, with corrected docs + tests.** For the
target workload — a bounded, trusted set of formulas, each compiled once and
cached (cache sized to hold them, so no eviction churn) — total atoms = number
of distinct formulas, once. Bounded and negligible. The 4–116× speedup and the
per-eval allocation drop stand. The remediation is documentation + tests, not a
code change:

- `native_compilation` ships **on by default** but only activates when the opt-in
  `ExCellerate.Supervisor` (or `NativeCompiler`) is started; absent that, the
  interpreted path is used. Set `native_compilation: false` (globally or
  per-registry) for **unbounded or untrusted** expression input.
- Task 9's atom test was rewritten: it no longer asserts a false "bounded under
  churn" property. It now asserts the real guarantee (re-evaluating a cached
  bounded set does not grow atoms — cache hits never recompile) plus a
  characterization test pinning the ~1-atom-per-distinct-compile cost.
- Docs (moduledoc + README) state plainly: native bounds code/memory, each
  distinct native compile costs ~1 atom, use native for bounded/trusted sets.

A future option (not built): cap total distinct native compiles via a global
counter and fall back to interpreted once exceeded, to bound the worst case
under unbounded input. Deferred — unnecessary for the target workload.
