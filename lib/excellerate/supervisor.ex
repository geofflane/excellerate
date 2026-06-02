defmodule ExCellerate.Supervisor do
  @moduledoc """
  Optional supervisor that starts ExCellerate's runtime processes:
  `ExCellerate.Cache` (compiled-expression cache) and
  `ExCellerate.NativeCompiler` (native module compiler/pool).

  Add it to your application's supervision tree as a single child:

      children = [ExCellerate.Supervisor, ...]

  If you do not start these processes, ExCellerate still works: caching is
  skipped and expressions are evaluated via the interpreter.
  """
  use Supervisor

  def start_link(opts \\ []), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    Supervisor.init([ExCellerate.Cache, ExCellerate.NativeCompiler], strategy: :one_for_one)
  end
end
