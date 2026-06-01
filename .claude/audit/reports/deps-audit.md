# ExCellerate Dependency Audit

Health score: **95 / 100**

## Dependency tree
| Package | Version | Scope | Notes |
|---------|---------|-------|-------|
| nimble_parsec | ~> 1.4 | **runtime** | Only runtime dep. Mature, Dashbit-maintained, ubiquitous. |
| benchee | ~> 1.3 | dev | Benchmarking. |
| ex_doc | ~> 0.34 | dev (`warn_if_outdated: true`) | Docs. |
| dialyxir | ~> 1.4 | dev/test | Static analysis. |
| credo | ~> 1.7 | dev/test | Linting. |

## Findings
- `mix hex.audit`: **no retired packages**.
- Single runtime dependency = minimal supply-chain surface. Excellent for a library.
- All non-runtime deps are standard, well-maintained tooling.
- Minor: `mix.exs` declares `dialyzer: [ignore_warnings: ".dialyzer_ignore.exs"]` but that
  file does not exist (dialyzer prints a harmless warning). Either create an empty file or
  drop the option.

## Recommendations
- Run `mix hex.outdated` periodically; consider `mix deps.audit` (mix_audit) in CI for CVE
  scanning. No action required now.
