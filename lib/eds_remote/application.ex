defmodule EDS.Remote.Application do
  use Application

  alias EDS.Utils.Code

  @remote_modules [
    __MODULE__,
    EDS.Remote.Trace.Server,
    EDS.Remote.Spy.Server,
    EDS.Remote.Spy.Server.State,
    EDS.Remote.Spy.Stack,
    EDS.Remote.Spy.Stack.Frame,
    EDS.Remote.Spy.Meta,
    EDS.Remote.Spy.Eval,
    EDS.Remote.Spy.Bindings,
    EDS.Remote.Proxy,
    EDS.Utils.Code,
    EDS.Utils.Mesh,
    :forms,
    :forms_pt,
    :meta
  ]

  def modules(), do: @remote_modules

  def bootstrap() do
    appspec =
      {:application, :eds_remote,
       [
         {:applications, [:kernel, :stdlib, :elixir, :logger, :runtime_tools, :debugger]},
         {:description, 'EDS remote application'},
         {:modules, @remote_modules},
         {:registered, []},
         {:mod, {__MODULE__, []}}
       ]}

    Code.redirect_breakpoint()
    :application.load(appspec)
    Application.ensure_all_started(:eds_remote, :permanent)
  end

  def start(_type, _args) do
    children = [
      EDS.Remote.Trace.Server,
      EDS.Remote.Spy.Server,
      EDS.Remote.Proxy
    ]

    opts = [strategy: :one_for_one, name: EDS.Remote.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
