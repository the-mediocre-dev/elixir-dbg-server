defmodule EDS.Remote.Trace.Server do
  use GenServer

  alias EDS.Utils.Mesh

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: Mesh.trace_server(Node.self()))
  end

  @impl true
  def init(state) do
    :erlang.trace(:all, true, [:call])

    {:ok, state, {:continue, {:cast, :sync}}}
  end

  @impl true
  def handle_continue({:cast, :sync}, state) do
    Node.self()
    |> Mesh.trace_proxy()
    |> GenServer.whereis()
    |> case do
      pid when is_pid(pid) ->
        GenServer.cast(Mesh.trace_proxy(Node.self()), {:sync_request, []})
        {:noreply, state}

      _else ->
        {:noreply, state, {:continue, {:cast, :sync}}}
    end
  end

  @impl true
  def handle_info({:trace, _, :return_from, {_mod, _fun, _arity}, _res}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(_message, state), do: {:noreply, state}

  @impl true
  def handle_cast({:sync, _}, state) do
    continue()

    :erlang.trace_pattern({:_, :_, :_}, false)
    :erlang.trace_pattern({List, :first, :_}, [{:_, [], [{:return_trace}]}])

    {:noreply, state}
  end

  @impl true
  def handle_cast(_message, state), do: {:noreply, state}

  defp continue() do
    if Process.whereis(:eds_bootsrapper) do
      send(:eds_bootsrapper, {:continue, %{}})
    end
  end
end
