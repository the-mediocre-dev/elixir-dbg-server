defmodule EDS.Remote.Trace.Server do
  use GenServer

  alias EDS.Utils.Mesh

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: Mesh.trace_server(Node.self()))
  end

  @impl true
  def init(state) do
    :erlang.trace(:all, true, [:call])

    {:ok, state}
  end

  def sync() do
    # :erlang.trace_pattern({:_, :_, :_}, false)
    # :erlang.trace_pattern({List, :first, :_}, [{:_, [], [{:return_trace}]}])
  end

  @impl true
  def handle_info({:trace, _, :return_from, {_mod, _fun, _arity}, _res}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(_message, state), do: {:noreply, state}

  @impl true
  def handle_cast(_message, state), do: {:noreply, state}
end
