defmodule ExCellerate.Application do
  @moduledoc false
  # Application callback. Starts ExCellerate's internal root supervisor so the
  # native-compilation process is available without consumers wiring it up. The
  # compiled-expression cache remains opt-in (add `ExCellerate.Cache` yourself).
  use Application

  @impl true
  def start(_type, _args) do
    ExCellerate.Supervisor.start_link([])
  end
end
