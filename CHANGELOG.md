# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
