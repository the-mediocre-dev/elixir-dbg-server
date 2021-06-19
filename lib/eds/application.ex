defmodule EDS.Application do
  use Application

  def start(_type, _args) do
    if(Node.self() == :nonode@nohost) do
      Node.start(:"eds@127.0.0.1")
    end

    children = [
      EDS.MeshServer,
      {Phoenix.PubSub, name: EDS.PubSub},
      EDSWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: EDS.Supervisor]

    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    EDSWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
