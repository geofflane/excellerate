defmodule ExCellerate.Supervisor do
  @moduledoc false
  # Internal root supervisor, started by ExCellerate.Application — NOT something
  # consumers add to their own tree.
  #
  # It starts ExCellerate.NativeCompiler only when the globally-configured
  # compilation strategy needs it (`compilation: ExCellerate.Compilation.NativeCompiled`),
  # so selecting native "just works" without manual supervision and nothing is
  # started for interpreted-only consumers.
  #
  # The compiled-expression cache (ExCellerate.Cache) is intentionally NOT
  # started here — it stays opt-in; add it to your own supervision tree.
  use Supervisor

  def start_link(opts), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    children =
      if native_configured?() do
        [ExCellerate.NativeCompiler]
      else
        []
      end

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp native_configured? do
    Application.get_env(:excellerate, :compilation, ExCellerate.Compilation.Interpreted) ==
      ExCellerate.Compilation.NativeCompiled
  end
end
