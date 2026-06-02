# ExCellerate Architecture Audit

Scope: module structure, cohesion/coupling, public API, function-dispatch/registration
mechanism, extensibility. Pure Elixir library — no web/Ecto concerns.

Health score: **85 / 100**

xref: 0 cycles. credo --strict: 3 readability nits + 8 design suggestions (mostly tests).

---

## Findings

### 1. Misleading "near-native performance" claim in the public moduledoc (Medium — accuracy)
`lib/excellerate.ex:6` states expressions are "compiled into native Elixir AST for
near-native performance." In reality `compile_to_function/2` uses `Code.eval_quoted`,
which yields an interpreted `:erl_eval` closure — never BEAM-compiled (see perf finding #1).
This is an architecture/documentation-honesty issue: the headline design promise of the
library is not realized. Either fix the implementation (real module generation) or soften
the docs. Recommend the former.

### 2. Two inconsistent function-resolution paths (Low — consistency/maintenance)
- Custom registries generate `resolve_function/1` pattern-match clauses at compile time
  (`registry.ex:91-96`) — fast, idiomatic.
- The default path (`functions.ex:78-80`) uses `Enum.find` calling `module.name()` —
  an O(n) linear scan over ~55 modules.

Two divergent mechanisms for the same job. The default (most common) path should reuse
the registry's compile-time map approach. Functional impact is cold-compile only (perf
finding #2), but the inconsistency is an architectural smell.

### 3. `functions.ex` central registration list is a hand-maintained hub (Low)
`@default_functions` (`functions.ex:5-70`) lists all ~55 modules explicitly (60 outgoing
deps; `function.ex` correspondingly has 60 incoming). This is the single edit point when
adding a function and is easy to forget. xref shows it as the top hub but with 0 cycles,
so it's a healthy hub, not a tangle. Consider compile-time discovery (e.g. a registration
macro in each function module collecting into a module attribute) to remove the manual list.

### 4. Design-debt markers (Low)
- `compiler.ex:33` `# TODO: Is there a way to do this once instead of every call?` — real;
  the runtime guard is redundant with compile-time resolution (perf finding #3).
- `compiler.ex:86` explicit `try` flagged by credo (`struct_get`) — prefer implicit `try`.

## Clean areas (one line)
- `Function` behaviour (`function.ex`) is well-designed and documented: `name/0`, `arity/0`
  (int | Range | :any), `call/1`; the `Guards` helper module is a good extensibility aid.
- Function-per-module pattern is consistent across general/ math/ datetime/.
- `Registry` `__using__`/`__before_compile__` macro is idiomatic; plugin-overrides-default
  resolution is correct and documented.
- Public API moduledoc is thorough (full operator + function reference tables).
- 0 cycles, clean layering: parser → IR → compiler → function dispatch.

## Score justification
Base strong (clean structure, idiomatic macros, documented behaviour, 0 cycles).
−10 for the inaccurate performance claim in the primary public moduledoc (#1).
−3 for the dual resolution-path inconsistency (#2).
−2 for the hand-maintained registration hub + TODO/try debt (#3, #4).
