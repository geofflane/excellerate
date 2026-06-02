defmodule ExCellerate.Compilation.Strategy do
  @moduledoc """
  Behaviour for turning a compiled IR (Elixir AST) into a callable evaluation
  function — i.e. *how* an expression is executed.

  Built-in strategies:

    * `ExCellerate.Compilation.Interpreted` (**default**) — evaluates via an
      interpreted `Code.eval_quoted/3` closure. Consumes no atoms per expression;
      the right choice for unbounded or untrusted input, and for expressions
      evaluated only a few times.
    * `ExCellerate.Compilation.NativeCompiled` — compiles each expression into a
      real, loaded BEAM module and evaluates it as compiled code (much faster on
      the warm path, far lower per-call allocation). Each distinct compiled
      expression consumes ~1 permanent atom, so use it for a bounded, trusted set
      of expressions evaluated many times.

  Select one globally with `config :excellerate, compilation: <strategy module>`
  or per-registry with `use ExCellerate.Registry, compilation: <strategy module>`.
  Custom strategies may implement this behaviour; a strategy that returns a
  non-nil `mod_name` is responsible for that module's purge lifecycle (see
  `ExCellerate.NativeCompiler`).
  """

  @doc """
  Builds an evaluation function from a compiled `elixir_ast`.

  Returns `{fun, mod_name}` where `fun` is a 1-arity function taking a scope map,
  and `mod_name` is the backing BEAM module (an atom) the cache must release on
  eviction, or `nil` when the strategy created no purgeable module.
  """
  @callback build(
              registry :: ExCellerate.registry(),
              expression :: String.t(),
              elixir_ast :: Macro.t()
            ) :: {(ExCellerate.scope() -> any()), atom() | nil}
end
