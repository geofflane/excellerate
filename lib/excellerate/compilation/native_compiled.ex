defmodule ExCellerate.Compilation.NativeCompiled do
  @moduledoc """
  Compilation strategy that compiles each expression into a real, loaded BEAM
  module (via `ExCellerate.NativeCompiler`) and evaluates it as compiled code.
  Substantially faster on the warm path with far lower per-call allocation than
  the interpreter. Opt in with `config :excellerate, compilation: __MODULE__`
  (the default strategy is `ExCellerate.Compilation.Interpreted`).

  The `ExCellerate.NativeCompiler` process this needs is started on demand the
  first time a native compile is requested (supervised by the `:excellerate`
  application's `ExCellerate.Supervisor`), so no supervision wiring is required
  and native works whether selected globally or only on a single registry. If it
  cannot be started — or a transient race causes the compile call to exit — this
  strategy degrades to `ExCellerate.Compilation.Interpreted` rather than crashing
  the caller; native compilation is a transparent optimization, never a
  correctness dependency.

  NOTE: `Module.create/3` interns ~1 permanent atom per distinct expression
  compiled. Use this strategy for a bounded, trusted set of expressions (cache
  sized to hold them); prefer `Interpreted` for unbounded/untrusted input.
  """
  @behaviour ExCellerate.Compilation.Strategy

  alias ExCellerate.Compilation.Interpreted
  alias ExCellerate.NativeCompiler

  @warn_flag :excellerate_native_exit_warned

  @impl true
  def build(registry, expression, elixir_ast) do
    case ExCellerate.Supervisor.ensure_native_compiler() do
      {:ok, _pid} ->
        try do
          {:ok, fun, mod_name} = NativeCompiler.compile_cached(registry, expression, elixir_ast)
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
