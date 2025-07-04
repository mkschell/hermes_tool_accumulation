defmodule HermesToolAccumulation.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Hermes.Server.Registry
    ]

    opts = [strategy: :one_for_one, name: HermesToolAccumulation.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
