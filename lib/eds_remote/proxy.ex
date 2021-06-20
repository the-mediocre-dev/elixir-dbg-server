defmodule EDS.Remote.Proxy do
  use GenServer

  alias EDS.Utils.Mesh

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: Mesh.remote_proxy(Node.self()))
  end

  @impl true
  def init(state) do
    :net_kernel.monitor_nodes(true)

    {:ok, state, {:continue, {:cast, :sync}}}
  end

  @impl true
  def handle_continue({:cast, :sync}, state) do
    Node.self()
    |> Mesh.proxy()
    |> GenServer.whereis()
    |> case do
      pid when is_pid(pid) ->
        GenServer.cast(Mesh.proxy(Node.self()), {:sync_request, []})
        {:noreply, state}

      _else ->
        {:noreply, state, {:continue, {:cast, :sync}}}
    end
  end

  @impl true
  def handle_info({:nodedown, :"eds@127.0.0.1"}, state) do
    [IO.ANSI.red(), "EDS connection lost. Aborting.", :reset]
    |> IO.ANSI.format_fragment()
    |> IO.puts()

    System.halt()

    {:noreply, state}
  end

  @impl true
  def handle_info(_message, state), do: {:noreply, state}

  @impl true
  def handle_cast({:sync, _}, state) do
    continue()

    {:noreply, state}
  end

  defp continue() do
    if Process.whereis(:eds_bootsrapper) do
      send(:eds_bootsrapper, {:continue, %{}})
    end
  end
end
