defmodule EDS.Application do
  use Application

  def start(_type, _args) do
    :os.cmd('epmd -daemon')

    if(Node.self() == :nonode@nohost) do
      Node.start(:"eds@127.0.0.1")
    end

    children = [
      EDS.Mesh,
      EDSWeb.Endpoint,
      {Registry, keys: :duplicate, name: EDS.Registry}
    ]

    children =
      case Mix.env() do
        :test -> children
        _else -> children ++ [EDS.Dispatcher]
      end

    :ets.new(EDS.Repo, [
      :bag,
      :named_table,
      :public,
      {:read_concurrency, true},
      {:write_concurrency, true}
    ])

    opts = [strategy: :one_for_one, name: EDS.Supervisor]

    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    EDSWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
