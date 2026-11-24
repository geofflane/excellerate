# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.0] - 2026-11-24

### Security

- A call on a computed value (`x.m(1)`, `list[0](1)`, `items[*].m()`, `abs(1)(2)`) dispatched to whatever module atom the evaluated value held, bypassing the registry allowlist. If the scope data contained a module atom exposing `call/1`, an expression could invoke it. Such calls are now rejected at compile time with a `:compiler` error; only names that resolve through the registry or defaults can be called.
- Unclosed nested `not(` (e.g. `not(not(not(…1`) took exponential time to reject: each level was parsed both as the `not` operator and as a call to a function named `not`, so an 81-byte expression took about 3.5 seconds and each extra level doubled that. `not` is now a reserved word and such input is rejected in linear time.

### Fixed

- Identifiers beginning with `not` (e.g. `notable`, `nothing`, `not_set`) were parsed as the `not` operator applied to the rest of the name, so `notable` evaluated as `not(able)`. The `not` keyword now requires a word boundary.
- Under `ExCellerate.Compilation.NativeCompiled`, a function returned by `compile/2` and held by the caller could silently evaluate a *different* expression after its cache entry was evicted and its pooled module slot reused (or raise `UndefinedFunctionError` once the slot was purged). Compiled modules are now generation-tagged, and returned functions detect a stale slot and transparently recompile, so held functions stay correct indefinitely.
- Under `ExCellerate.Compilation.NativeCompiled`, a cached expression could hang its caller forever after `ExCellerate.NativeCompiler` restarted (or, rarely, after an eviction raced a compile): the restarted pool reused the cached function's module name, and the function's recovery recompiled through the cache, got the same stale function back, and retried endlessly. Recovery now drops the stale cache entry before recompiling and always terminates, and a restarted `NativeCompiler` drops native cache entries and unloads its predecessor's modules.
- A key missing from the rows of a large list (`rows[*].nope`, including nested and computed spreads) took quadratic time: each miss raised and rescued an exception inside the spread's body-recursive loop, and an exception's cost grows with the stack depth. 40,000 rows took about 3.4 seconds instead of 19 ms. Spreads now iterate tail-recursively, so a miss costs about the same as a hit. Results are unchanged.
- `ExCellerate.Cache.clear/0` now releases the native modules behind the entries it drops. Previously their pool slots were never returned.

### Changed

- `not` is now a reserved word, like `true`, `false`, and `null`. A bare variable named `not` (`eval("not", %{"not" => 1})`) and a registry function named `not` are no longer usable; a key named `not` is still reachable through its parent (`row.not`, `row['not']`).
- `if`, `ifs`, `ifnull`, `coalesce`, `switch`, `and`, and `or` now evaluate only the arguments they need, like `&&`, `||`, and the ternary. Previously every argument was evaluated first, so `if(x != 0, 10 / x, 0)` raised when `x` was `0`. Results are unchanged for any expression that did not raise. A registry's own function with one of these names is still called normally.
- `ExCellerate.Cache` no longer writes on every hit: a hit records recency only if the entry has not been used since the last insert, so reads of hot expressions from many processes stop contending on the same rows (about 13× faster per hit with 14 concurrent readers). Insertion keeps a per-registry entry count instead of counting the table on every `put`. Entries read between the same two inserts now count as equally recent for eviction.
- `ExCellerate.NativeCompiler` logs a one-time warning when its module pool fills, since new expressions then silently lose native compilation.
- Documentation: corrected the native atom-cost note. The cost is 1 atom per native *compile* (including a recompile after cache eviction), not per distinct expression, so size `cache_limit` to hold every distinct expression. Also documented that the module pool is shared across registries.

## [0.4.0] - 2026-06-18

### Added

- Pluggable compilation strategies (`ExCellerate.Compilation.Strategy`): `ExCellerate.Compilation.Interpreted` (default) uses the interpreter; `ExCellerate.Compilation.NativeCompiled` compiles each expression into a real BEAM module and evaluates it as compiled code (substantially faster on the warm path, much lower per-call allocation). Opt into native globally or per-registry. Native is intended for a bounded, trusted set of expressions — each distinct natively-compiled expression consumes ~1 atom (see the README); the default `Interpreted` strategy is the safe choice for unbounded/untrusted input.
- The `ExCellerate.NativeCompiler` process is started on demand the first time a native compile happens (supervised by the `:excellerate` application), so opting into native compilation requires no supervision wiring and works whether native is selected globally or per-registry. The `ExCellerate.Cache` remains opt-in — add it to your supervision tree.
- Configuration: `compilation` strategy (global and per-registry), `native_module_limit`, and `native_purge_grace_ms`.
- Configurable resource limits: `max_expression_length` (default 10,000 bytes), `max_expression_depth` (default 100), and `max_factorial_input` (default 10,000).

### Changed

- `factorial` is now tail-recursive and rejects operands above `max_factorial_input`.
- Documentation: described caching and compilation accurately (removed the inaccurate "near-native performance" / "native execution speed" claims, which did not match the interpreted `Code.eval_quoted` path).

### Security

- Reject oversized expressions (`max_expression_length`) before parsing and deeply-nested expressions (`max_expression_depth`) before compilation, preventing parse/compile resource exhaustion from adversarial input.
- Cap the `factorial` operand to prevent CPU/memory exhaustion from a tiny input (e.g. `999999999!`).

## [0.3.0] - 2026-03-11

### Added

- Date and time functions: `date`, `datetime`, `today`, `now`, `year`, `month`, `day`, `hour`, `minute`, `second`, `weekday`, `datedif`, `dateadd`
- Singular and plural unit names accepted by `datedif` and `dateadd` (e.g., `"day"` or `"days"`)
- Guard helpers `ensure_date_or_datetime!/2` and `ensure_date_unit!/2` for runtime type validation of date/time values

### Fixed

- Ensure linebreaks work around column expressions

## [0.2.0] - 2026-03-09

### Added

- `sort` and `unique` functions
- Negative indexes to work from the end of collections
- Runtime type checking backfilled to more builtin functions
- Variable precedence confirmation for computed spreads

### Changed

- Updated dependencies
- Cleaned up `take` function and resolved Credo warnings

## [0.1.0] - 2026-03-05

### Added

- Initial release
- Expression parser and evaluator with spreadsheet-style formula syntax
- Arithmetic, comparison, and logical operators
- String functions: `upper`, `lower`, `trim`, `concat`, `slug`, `underscore`, `left`, `right`, `mid`, `len`, `substitute`, `rept`, `exact`
- Math functions: `abs`, `round`, `floor`, `ceil`, `min`, `max`, `sum`, `avg`, `power`, `mod`, `factorial`
- Collection functions: `take`, `slice`, `index`, `match`, `filter`, `table`, `let`
- Utility functions: `if`, `ifs`, `isnull`, `isblank`, `coalesce`
- Null propagation for path access
- Multi-line expression support
- Columnar data access via spread operator
- Computed spread expressions
- Struct, string-keyed map, and atom-keyed map support
- LRU caching for compiled expressions
- Custom function registration
- Dialyzer and Credo compliance
- Security documentation for expression evaluation

[0.3.0]: https://github.com/geofflane/excellerate/compare/0.2.0...0.3.0
[0.2.0]: https://github.com/geofflane/excellerate/compare/0.1.0...0.2.0
[0.1.0]: https://github.com/geofflane/excellerate/releases/tag/0.1.0
