# ExCellerate — Project Health Audit

**Date:** 2026-06-01 · **Commit:** main @ c4e41b7 · **Type:** pure Elixir library (expression-evaluation engine)

## Executive Summary

ExCellerate is a **healthy, mature, exceptionally well-tested** library. Static-analysis
hygiene is near-spotless: clean `--warnings-as-errors` compile, 0 dialyzer errors, 0 xref
cycles, near-clean credo, 549 tests + 47 doctests passing in 0.2s at 92.87% coverage, and a
single runtime dependency.

The **one strategic issue** dominates the score: the library's headline promise — "compiles
into native Elixir AST for near-native performance" — is **not realized**. `Code.eval_quoted`
produces an interpreted `:erl_eval` closure, so every evaluation runs the interpreter rather
than compiled BEAM code. This is simultaneously a performance finding (#1, perf) and a
documentation-accuracy finding (#1, arch). Secondary themes: a few input-driven DoS vectors
(no parse depth/size limits; unbounded factorial) and the custom-registry extensibility path
sitting at 0% test coverage.

**Overall: 80 / 100 — Grade B.** A solidly-built library with one high-leverage
implementation gap between its stated and actual performance characteristics.

## Health Scores

| Category | Score | Grade | Headline |
|----------|------:|:-----:|----------|
| Architecture | 85 | B+ | Clean, idiomatic, 0 cycles; perf claim in docs is inaccurate |
| Performance | 58 | F | `Code.eval_quoted` → interpreted closure, not native; redundant per-call guards |
| Security | 78 | C+ | No ACE, no atom exhaustion; DoS via unbounded recursion/factorial |
| Tests | 82 | B | 92.87% cover, 549+47 green; Registry 0%, no property tests |
| Dependencies | 95 | A | Single runtime dep, no retired/vulnerable packages |
| **Overall** | **80** | **B** | Healthy library; one strategic perf/accuracy gap |

## Critical & High-Priority Issues

1. **[Perf CRITICAL / Arch] `Code.eval_quoted` yields an interpreted closure**
   (`excellerate.ex:446-465`, claim at `excellerate.ex:6`). Both cold compile and every warm
   eval run the `:erl_eval` interpreter — likely 1–2 orders of magnitude slower than the
   claimed "near-native." **Cross-category correlation:** also an architecture/docs-honesty
   issue. Fix: generate real modules via `Module.create/3` + `Code.compile_quoted`, cache the
   `&Mod.eval/1` capture, and **purge generated modules on cache eviction** (`:code.purge/1`)
   to avoid a code-memory leak (perf finding #5).

2. **[Security High] No depth/size limit on parse + compile** (`parser.ex`, `compiler.ex:154`).
   Deeply nested input (`((((…))))`) can exhaust stack/CPU/memory before evaluation. Add a
   byte-length cap pre-parse and an AST depth/node-count guard.

3. **[Security High] Unbounded `factorial`** (`math.ex:8`). `999999999!` builds an
   astronomical bignum from a tiny string — trivial single-expression DoS. Cap the operand
   and make it tail-recursive.

4. **[Tests High] `ExCellerate.Registry` at 0% coverage.** The primary extensibility
   mechanism (custom function plugins) is entirely untested.

## Top Recommendations

### Immediate (this week)
- Add input-length + AST-depth guards (security #1) and cap `factorial` (security #2) — small,
  high-value hardening with matching tests.
- Add a test/support custom registry to cover `ExCellerate.Registry` (tests #1).
- Either soften the "near-native performance" moduledoc claim **or** commit to the module-
  generation fix below; don't ship the inaccurate claim.

### Short-term (this month)
- **Replace `Code.eval_quoted` with genuine module compilation** + eviction-time module
  purge. This is the single highest-leverage change in the project. Pair it with a benchmark
  that baselines against a hand-written native function so the win is measurable (perf #7).
- Drop the redundant per-call `ensure_loaded?`/`function_exported?`/arity guards for
  compile-time-resolved calls (perf #3 / the `compiler.ex:33` TODO).
- Build a compile-time `%{name => module}` map for default-function resolution to replace the
  `Enum.find` linear scan (perf #2 / arch #2) — unifies the two resolution paths.

### Long-term / nice-to-have
- Introduce property-based tests (StreamData) over parse→compile→eval (tests #2).
- Stop embedding raw exceptions in `Error.details` (security #3, low).
- Cache improvements: avoid per-put `select_count` + O(n log n) eviction; reconsider write-on-
  read LRU touch (perf #4).
- Housekeeping: remove the TODO/explicit-`try`/test credo nits; create or drop the missing
  `.dialyzer_ignore.exs`; consider compile-time function discovery to retire the hand-
  maintained `@default_functions` list.

## Method & Caveats
- Quick pulse run first (Iron Law #4): compile, test, xref, credo, dialyzer, hex.audit.
- 4 parallel specialist auditors (architecture, performance, security, tests); dependency
  audit folded into synthesis (tiny dep tree). Phoenix/Ecto/LiveView/Oban tracks N/A — this
  is a pure library; security was scoped to the relevant threat model (injection / sandbox
  escape / resource exhaustion).
- Architecture & test reports were reconstructed inline (those two agents completed analysis
  but did not persist their files; findings re-derived from direct reads + coverage data).
- Scores are project-internal trend baselines — do not compare across projects (Iron Law #3).

Reports: `.claude/audit/reports/{arch-review,perf-audit,security-audit,test-audit,deps-audit}.md`
