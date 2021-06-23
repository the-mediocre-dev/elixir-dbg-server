defmodule EDS.Remote.Proxy do
  use GenServer

  alias EDS.Utils.Mesh

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: Mesh.remote_proxy(Node.self()))
  end

  @impl true
  def init(state) do
    :net_kernel.monitor_nodes(true)

    {:ok, state, {:continue, :node_init}}
  end

  @impl true
  def handle_continue(:node_init, state) do
    Node.self()
    |> Mesh.proxy()
    |> GenServer.whereis()
    |> case do
      pid when is_pid(pid) ->
        Node.self()
        |> Mesh.proxy()
        |> GenServer.cast({:node_init, Node.self()})

        {:noreply, state}

      _else ->
        {:noreply, state, {:continue, :node_init}}
    end
  end

  @impl true
  def handle_cast({:node_init, %{spies: _spies, traces: traces}}, state) do
    Node.self()
    |> Mesh.trace_server()
    |> GenServer.call({:insert, traces})

    Node.self()
    |> Mesh.proxy()
    |> GenServer.cast({:node_init_ack, Node.self()})

    continue()

    {:noreply, state}
  end

  @impl true
  def handle_info({:nodedown, :"eds@127.0.0.1"}, state) do
    [IO.ANSI.red(), "EDS connection lost. Aborting.", :reset]
    |> IO.ANSI.format_fragment()
    |> IO.puts()

    System.halt()

    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp continue() do
    if Process.whereis(:eds_bootsrapper) do
      send(:eds_bootsrapper, {:continue, %{}})
    end
  end
end
