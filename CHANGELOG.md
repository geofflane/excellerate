# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/geofflane/excellerate/compare/0.3.0...HEAD
[0.3.0]: https://github.com/geofflane/excellerate/compare/0.2.0...0.3.0
[0.2.0]: https://github.com/geofflane/excellerate/compare/0.1.0...0.2.0
[0.1.0]: https://github.com/geofflane/excellerate/releases/tag/0.1.0
