defmodule EDS.Remote.Application do
  use Application

  @remote_modules [
    __MODULE__,
    EDS.Remote.Trace.Server,
    EDS.Remote.MeshMonitor,
    EDS.Utils.Mesh
  ]

  def modules(), do: @remote_modules

  def bootstrap() do
    appspec =
      {:application, :eds_remote,
       [
         {:applications, [:kernel, :stdlib, :elixir, :logger, :runtime_tools]},
         {:description, "EDS remote application"},
         {:modules, @remote_modules},
         {:registered, []},
         {:mod, {__MODULE__, []}}
       ]}

    :application.load(appspec)
    :application.ensure_all_started(:eds_remote, :permanent)
  end

  def start(_type, _args) do
    children = [
      EDS.Remote.Trace.Server,
      EDS.Remote.MeshMonitor
    ]

    opts = [strategy: :one_for_one, name: EDS.Remote.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
