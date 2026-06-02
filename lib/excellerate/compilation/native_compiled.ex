defmodule ExCellerate.Compilation.NativeCompiled do
  @moduledoc """
  Compilation strategy that compiles each expression into a real, loaded BEAM
  module (via `ExCellerate.NativeCompiler`) and evaluates it as compiled code.
  Substantially faster on the warm path with far lower per-call allocation than
  the interpreter. This is the default strategy.

  Requires `ExCellerate.NativeCompiler` to be running (start it via
  `ExCellerate.Supervisor`). If it is not running — or a transient race causes
  the compile call to exit — this strategy degrades to
  `ExCellerate.Compilation.Interpreted` rather than crashing the caller; native
  compilation is a transparent optimization, never a correctness dependency.

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
    if Process.whereis(NativeCompiler) != nil do
      try do
        {:ok, fun, mod_name} = NativeCompiler.compile_cached(registry, expression, elixir_ast)
        {fun, mod_name}
      catch
        # TOCTOU: NativeCompiler can crash, be restarted by its supervisor, or
        # time out between the whereis check above and this GenServer.call,
        # surfacing as an EXIT (`:noproc`, `:shutdown`, `:timeout`, ...). Degrade
        # to the pure interpreted closure rather than crash the (hot-path) caller.
        :exit, reason ->
          warn_unavailable_once(reason)
          {Interpreted.build_fun(elixir_ast), nil}
      end
    else
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
