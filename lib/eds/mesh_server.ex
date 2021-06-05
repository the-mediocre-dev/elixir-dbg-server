defmodule EDS.MeshServer do
  use GenServer

  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(args) do
    :net_kernel.monitor_nodes(true)

    args
    |> EDS.DynamicSupervisor.start_link()
    |> case do
      {:ok, _pid} -> {:ok, %{nodes: %{}}}
      error -> error
    end
  end

  @impl true
  def handle_info({:nodeup, node}, state) do
    {EDS.TraceProxy, node: node}
    |> EDS.DynamicSupervisor.start_child()
    |> case do
      {:ok, pid} ->
        {:noreply, push_node(state, node, pid)}

      error ->
        Logger.error("Failed to attach remote node #{node}")
        Logger.error("#{inspect(error)}")

        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:nodedown, node}, state) do
    state
    |> get_in([:nodes, node])
    |> EDS.DynamicSupervisor.terminate_child()
    |> case do
      response when response in [:ok, {:error, :not_found}] ->
        {:noreply, pop_node(state, node)}

      error ->
        Logger.error("Failed to detach remote node #{node}")
        Logger.error("#{inspect(error)}")

        {:noreply, state}
    end
  end

  @impl true
  def handle_info(_message, state), do: {:noreply, state}

  defp push_node(state, node, pid) do
    put_in(state, [:nodes, node], pid)
  end

  defp pop_node(state, node) do
    state
    |> pop_in([:nodes, node])
    |> elem(1)
  end
end
