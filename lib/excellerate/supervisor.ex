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

  @doc false
  # Child spec for ExCellerate.NativeCompiler. Public so tests can start the
  # compiler with the same wiring the supervisor uses. On every (re)start the
  # compiler drops cached native funs, whose modules belonged to the previous
  # server. Passed as an MFA so NativeCompiler doesn't depend on Cache, which
  # depends on it.
  def native_compiler_spec(opts \\ []) do
    {ExCellerate.NativeCompiler,
     Keyword.put_new(opts, :on_init, {ExCellerate.Cache, :drop_native_entries, []})}
  end

  defp start_native_compiler do
    if Process.whereis(__MODULE__) do
      case DynamicSupervisor.start_child(__MODULE__, native_compiler_spec()) do
        {:ok, pid} -> {:ok, pid}
        {:error, {:already_started, pid}} -> {:ok, pid}
        {:error, _reason} -> :error
      end
    else
      :error
    end
  end
end
