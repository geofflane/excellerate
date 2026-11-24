defmodule ExCellerate.Compilation.NativeCompiled do
  @moduledoc """
  Compilation strategy that compiles each expression into a real, loaded BEAM
  module (via a dedicated native compiler process) and evaluates it as compiled code.
  Substantially faster on the warm path with far lower per-call allocation than
  the interpreter. Opt in with `config :excellerate, compilation: __MODULE__`
  (the default strategy is `ExCellerate.Compilation.Interpreted`).

  The native compiler process this needs is started on demand the first time a
  native compile is requested (supervised by the `:excellerate` application), so
  no supervision wiring is required
  and native works whether selected globally or only on a single registry. If it
  cannot be started — or a transient race causes the compile call to exit — this
  strategy degrades to `ExCellerate.Compilation.Interpreted` rather than crashing
  the caller; native compilation is a transparent optimization, never a
  correctness dependency.

  NOTE: every native compile permanently interns 1 atom (Elixir's module
  compiler names a temporary module per `Module.create/3`), including a
  recompile after the expression is evicted from the cache. Use this strategy
  for a bounded, trusted set of expressions with `cache_limit` sized to hold
  them all, so each compiles once; prefer `Interpreted` for unbounded/untrusted
  input.
  """
  @behaviour ExCellerate.Compilation.Strategy

  alias ExCellerate.Compilation.Interpreted
  alias ExCellerate.NativeCompiler

  @warn_flag :excellerate_native_exit_warned
  @recovering :excellerate_native_recovering

  @impl true
  def build(registry, expression, elixir_ast) do
    case ExCellerate.Supervisor.ensure_native_compiler() do
      {:ok, _pid} ->
        try do
          on_stale = fn scope, stale_mod ->
            recompile_and_run(registry, expression, scope, stale_mod)
          end

          {:ok, fun, mod_name} =
            NativeCompiler.compile_cached(registry, expression, elixir_ast, on_stale)

          {fun, mod_name}
        catch
          # TOCTOU: NativeCompiler can crash, be restarted, or time out between
          # ensure_native_compiler/0 above and this GenServer.call, surfacing as
          # an EXIT (`:noproc`, `:shutdown`, `:timeout`, ...). Degrade to the pure
          # interpreted closure rather than crash the (hot-path) caller.
          :exit, reason ->
            warn_unavailable_once(reason)
            {Interpreted.build_fun(elixir_ast), nil}
        end

      :error ->
        # The compiler could not be started (e.g. the :excellerate application /
        # ExCellerate.Supervisor is not running). Native is a transparent
        # optimization, so fall back to the interpreter.
        warn_unavailable_once(:native_compiler_unavailable)
        {Interpreted.build_fun(elixir_ast), nil}
    end
  end

  # A function returned by compile/2 can outlive its module: its cache entry was
  # evicted and its pooled slot released, or NativeCompiler restarted. It then
  # evaluates by compiling the expression again through ExCellerate.compile/2, so
  # the new module is cached (and later released by eviction) like any other.
  #
  # The cache may still hold this same stale fun (a restart, or an eviction that
  # raced a put), and compile/2 would hand it straight back, looping forever. So
  # first drop any entry still bound to the stale module.
  #
  # If the fresh module also goes stale before it runs (another restart or
  # eviction in between), recovery re-enters for the same expression. That call
  # is evaluated interpreted instead of retrying, so recovery always terminates.
  defp recompile_and_run(registry, expression, scope, stale_mod) do
    key = {@recovering, registry, expression}

    if Process.get(key) do
      run_interpreted(registry, expression, scope)
    else
      Process.put(key, true)

      try do
        ExCellerate.Cache.delete_stale(registry, expression, stale_mod)

        case ExCellerate.compile(expression, registry) do
          {:ok, fun} -> fun.(scope)
          {:error, error} -> raise error
        end
      after
        Process.delete(key)
      end
    end
  end

  defp run_interpreted(registry, expression, scope) do
    case ExCellerate.Parser.parse(expression) do
      {:ok, ast} -> Interpreted.build_fun(ExCellerate.Compiler.compile(ast, registry)).(scope)
      {:error, error} -> raise error
    end
  end

  # Logs once (like Cache.maybe_warn_not_started/0) so a *persistent* NativeCompiler
  # failure is diagnosable rather than silently degrading the hot path forever. A
  # transient TOCTOU exit warns once and is otherwise harmless.
  defp warn_unavailable_once(reason) do
    unless :persistent_term.get(@warn_flag, false) do
      :persistent_term.put(@warn_flag, true)
      require Logger

      Logger.warning(
        "ExCellerate.NativeCompiler exited during compilation (#{inspect(reason)}); " <>
          "falling back to interpreted evaluation. This warning is logged once."
      )
    end
  end
end
