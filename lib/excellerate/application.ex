defmodule ExCellerate.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {ExCellerate.Cache, []}
    ]

    opts = [strategy: :one_for_one, name: ExCellerate.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
