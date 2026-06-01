# ExCellerate Test Health Audit

Suite: 549 tests + 47 doctests, **0 failures, 0.2s**. 12 `*_test.exs` files + test/support.
Coverage (mix test --cover, ExCellerate.Test.* ignored per mix.exs): **92.87% total**.

Health score: **82 / 100**

---

## Findings

### 1. `ExCellerate.Registry` at 0% coverage — extensibility path untested (High)
The custom-function registry — the library's primary extension mechanism — has **0%
coverage**. The macro-generated `resolve_function/1` clauses, the generated `eval/2` &
`eval!/2` helpers, `list_functions/0`, plugin-overrides-default resolution, and
`__excellerate_config__` (cache_enabled/cache_limit) appear to have no dedicated test.
This is the highest-value gap: a public, documented feature that consumers depend on,
entirely unverified. Add a test/support registry with plugins (including one that
overrides a default by name) and assert resolution + eval + config behavior.

### 2. No property-based testing (Medium — high value for a parser/evaluator)
No `StreamData` / `ExUnitProperties` anywhere in test/. A parser+evaluator is the canonical
beneficiary: generate random valid expressions and assert parse→compile→eval never crashes;
round-trip numeric/string identities; operator-precedence invariants. Would surface edge
cases example-based tests miss (and the DoS inputs from the security audit).

### 3. No resource-limit / DoS tests (Medium — ties to security findings)
No tests for deeply nested expressions, oversized input, or large `factorial` (security
findings #1, #2). When limits are added, add tests asserting they reject gracefully with
`ExCellerate.Error` rather than exhausting resources.

### 4. Coverage gaps in core + a few functions (Low–Medium)
- `Compiler` 82.17% — the most complex module; the lowest-covered uncovered branches here
  are the most valuable to close (error/rescue paths, dynamic-dispatch branch).
- `Functions.DateTime.Dateadd` 76.92%, `General.Index` 85.71%, `Cache` 92.68%,
  `Parser` 95%, `Datedif` 95.56%, `Take` 95.65%.
- Most function modules sit at 100% — gaps are concentrated, not diffuse.

### 5. Credo nits in tests (Low)
- `datetime_functions_test.exs` (lines 688–733): nested modules should be aliased at top.
- `parser_test.exs:31,76`: quote-heavy string literals — use a sigil (`~S`).

## Clean areas (one line)
- Strong breadth: 549 tests + 47 doctests, fast (0.2s), fully async-safe, 0 failures.
- Error paths ARE tested broadly (`assert_raise`/`:error`/`ExCellerate.Error` across 10 files).
- Doctests present on the public API; per-function test files mirror lib/ structure.

## Score justification
Base high (broad, fast, green suite; 92.87% coverage; error paths covered).
−10 for the 0%-covered Registry extensibility path (#1).
−5 for absence of property-based testing on a parser/evaluator (#2).
−3 for missing resource-limit tests (#3), −0 (informational) for the concentrated coverage
gaps and credo nits.
