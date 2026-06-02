defmodule ExCellerate.Supervisor do
  @moduledoc false
  # Internal DynamicSupervisor, started (empty) by ExCellerate.Application — NOT
  # something consumers add to their own tree.
  #
  # It owns ExCellerate.NativeCompiler, which is started ON DEMAND the first time
  # a native compile is requested (see ExCellerate.Compilation.NativeCompiled).
  # Starting on use rather than at boot means nothing runs for interpreted-only
  # use, and native compilation works whether it is selected globally or only on
  # a single registry — the registry's strategy is known at the moment it is used.
  #
  # The compiled-expression cache (ExCellerate.Cache) is intentionally NOT started
  # here — it stays opt-in; add it to your own supervision tree.
  use DynamicSupervisor

  def start_link(opts), do: DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts), do: DynamicSupervisor.init(strategy: :one_for_one)

  @doc false
  # Ensures ExCellerate.NativeCompiler is running under this supervisor, starting
  # it on first use. Returns {:ok, pid}, or :error if it cannot be started (e.g.
  # this supervisor is not running because the :excellerate application has not
  # started). Safe under concurrent first-use (start_child races resolve to the
  # single registered instance).
  def ensure_native_compiler do
    case Process.whereis(ExCellerate.NativeCompiler) do
      nil -> start_native_compiler()
      pid -> {:ok, pid}
    end
  end

  defp start_native_compiler do
    if Process.whereis(__MODULE__) do
      case DynamicSupervisor.start_child(__MODULE__, ExCellerate.NativeCompiler) do
        {:ok, pid} -> {:ok, pid}
        {:error, {:already_started, pid}} -> {:ok, pid}
        {:error, _reason} -> :error
      end
    else
      :error
    end
  end
end
