defmodule EDS.Proxy do
  use GenServer

  alias EDS.Utils.Mesh

  @dispatcher Application.get_env(:eds, :dispatcher)

  def start_link([node: node] = args) do
    GenServer.start_link(__MODULE__, args, name: Mesh.proxy(node))
  end

  @impl true
  def init([node: node] = state) do
    # boot elixir on slave node during tests
    if(Mix.env() === :test) do
      :rpc.call(node, :code, :add_paths, [:code.get_path()])

      for application <- [:elixir, :kernel, :stdlib, :mix, :logger] do
        :rpc.call(node, Application, :ensure_all_started, [application])

        application
        |> Application.spec()
        |> Keyword.get(:modules)
        |> Enum.each(fn module ->
          :rpc.call(node, :code, :ensure_loaded, [module])
        end)
      end

      :rpc.call(node, Logger, :configure, [[level: Logger.level()]])
      :rpc.call(node, Mix, :env, [Mix.env()])
    end

    for module <- EDS.Remote.Application.modules() do
      {mod, bin, fun} = :code.get_object_code(module)
      :rpc.call(node, :code, :load_binary, [mod, fun, bin])
    end

    :rpc.call(node, EDS.Remote.Application, :bootstrap, [])

    {:ok, state}
  end

  @impl true
  def handle_call({:trace, op, trace}, _pid, [node: node] = state) do
    node
    |> Mesh.trace_server()
    |> GenServer.call({op, [trace]})

    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:node_init, node}, state) do
    mfas = %{
      spies: [],
      traces: EDS.Repo.debugged_mfas(node, :trace)
    }

    GenServer.cast(Mesh.remote_proxy(node), {:node_init, mfas})

    {:noreply, state}
  end

  def handle_cast({:node_init_ack, node}, state) do
    @dispatcher.node_ready(node)

    {:noreply, state}
  end

  def handle_cast({:trace_event, node, {{module, function, arity}, response}}, state) do
    @dispatcher.trace_event(node, "#{inspect(module)}/#{function}/#{arity}", response)

    {:noreply, state}
  end
end
