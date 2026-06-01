# Security Audit: ExCellerate

Threat model: untrusted expression strings parsed/compiled/evaluated. Surfaces:
injection, sandbox escape, resource exhaustion, info disclosure.

## Executive Summary

The two headline risks for an evaluator — **arbitrary code execution** and **atom
exhaustion** — are both **NOT exploitable**. Function names are resolved through a
fixed allowlist by string comparison and dispatched only to pre-registered modules'
`call/1`; user strings never become atoms (`String.to_existing_atom/1` is used
everywhere). The real exposure is **resource exhaustion** (no depth/size limits on
parse or eval; unbounded factorial bignum) and **information disclosure** via raw
exceptions in `Error.details`.

Security health score: **78 / 100**.

## Findings

### 1. No recursion/size limit on parse and compile — stack/CPU/memory DoS
- **Severity**: High
- **Location**: `lib/excellerate/parser.ex` (recursive `parsec` levels), `lib/excellerate/compiler.ex:154` `to_elixir_ast/2` (mutual recursion), `lib/excellerate.ex:446` `compile_to_function/2`
- **Attack**: A deeply nested input such as `((((((...1...))))))` or `-(-(-(...)))`,
  thousands deep, drives unbounded recursion in NimbleParsec and in `to_elixir_ast/2`.
  There is no maximum nesting depth, expression length, or AST node count. This can
  exhaust the scheduler stack / spike memory during parse and compile, before any
  evaluation. The compiled AST is then handed to `Code.eval_quoted/3`, paying full
  compile cost for attacker-sized input. `eval/3` and `compile_to_function/2` both
  `rescue`, but a process-killing memory blowup or very long compile is still a DoS,
  and the cost is incurred even on the failing path.
- **Fix**: Enforce a hard input-length cap (e.g. `byte_size(expression) > 10_000 ->
  {:error, ...}`) before parsing, and a max-depth/node-count guard while walking the
  IR in `to_elixir_ast/2` (raise an `ExCellerate.Error` when depth exceeds a bound,
  e.g. 100). Document the limits.

### 2. Unbounded factorial — bignum CPU/memory exhaustion + stack growth
- **Severity**: High
- **Location**: `lib/excellerate/math.ex:8` `factorial(n) when n > 0, do: n * factorial(n - 1)`
- **Attack**: `999999999!` triggers non-tail recursion building an astronomically
  large integer. Erlang bignums are arbitrary precision, so this consumes unbounded
  CPU and memory (and stack, since the recursion is not tail-call optimized) from a
  tiny input string. Trivial single-expression DoS.
- **Fix**: Cap the operand, e.g. `def factorial(n) when n > 10_000, do: raise
  ExCellerate.Error, message: "factorial argument too large", type: :runtime`. Make
  the recursion tail-recursive with an accumulator as a secondary hardening.

### 3. Information disclosure via raw exception in `Error.details`
- **Severity**: Low
- **Location**: `lib/excellerate/compiler.ex:50` (`details: e`), `lib/excellerate/error.ex:5,12`
- **Attack**: When a built-in/custom function raises a non-`ExCellerate.Error`, the
  original exception struct is attached to `details` and the message is interpolated
  into the user-facing error. For library functions this is benign, but a custom
  registry function that raises (e.g. an internal `KeyError`/`File.Error`/DB error)
  will leak internal structure/paths/values to whatever consumes the error. The raw
  exception (and its embedded data) crosses the trust boundary back to the caller.
- **Fix**: Do not embed the raw exception by default. Keep a generic message
  (`"function 'x' failed"`) and gate `details:` behind an explicit opt-in/debug flag.
  Avoid interpolating `Exception.message(e)` from untrusted custom functions.

### 4. `^` exponent compiles to `:math.pow/2` — float overflow
- **Severity**: Low
- **Location**: `lib/excellerate/compiler.ex:514` `:^ -> :math.pow(...)`
- **Attack**: `2 ^ 100000` etc. `:math.pow` returns a float and raises
  `ArithmeticError` on overflow rather than building a bignum, so it is bounded —
  but it changes integer semantics and the raise is caught by the eval `rescue`.
  Low risk; note that exponent does NOT enable bignum DoS (unlike factorial).
- **Fix**: None required; optionally validate exponent magnitude for clearer errors.

## Clean Areas (verified, no action)

- **Arbitrary code execution: NOT possible.** `dispatch_call/2` (compiler.ex:22)
  only invokes `module.call/1` for modules resolved at compile time from the registry
  allowlist or `Functions.list_defaults/0`. User strings become literals/keys/var
  names, never module or function atoms. `Code.eval_quoted` (excellerate.ex:456)
  evaluates only compiler-generated AST, not user text.
- **Atom exhaustion: NOT possible.** No `String.to_atom`/`binary_to_atom` in `lib/`.
  All conversions use `String.to_existing_atom/1` wrapped in `rescue ArgumentError`
  (compiler.ex:87, 108, 130; compiler.ex:441 `spread_access`).
- **ReDoS: not present.** All `Regex`/`String.replace` use fixed literal patterns
  (`slug.ex`, `underscore.ex`); user input is never compiled into a regex. `replace`,
  `find`, `contains` use literal `String`/`:binary` matching, not regex.
- **Unsafe deserialization:** no `:erlang.binary_to_term`.
- **DateTime (`now`/`today`):** nondeterminism only; no security impact.
- **Cache:** LRU-bounded per registry (cache.ex), so attacker-varied expressions
  cannot grow memory unbounded; ETS table is `:public` but holds only compiled funcs.

## Recommendations (priority order)
1. Add input-length + AST-depth limits (Finding 1).
2. Cap factorial operand (Finding 2).
3. Stop leaking raw exceptions in `Error.details` (Finding 3).

## Tools to Run Manually (no Bash in this agent)
- `mise exec -- mix sobelow --exit medium`
- `mise exec -- mix deps.audit`
- `mise exec -- mix hex.audit`
