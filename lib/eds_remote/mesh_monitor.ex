defmodule EDS.Remote.MeshMonitor do
  use GenServer

  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  def init(state) do
    :net_kernel.monitor_nodes(true)

    {:ok, state}
  end

  @impl true
  def handle_info({:nodedown, :"eds@127.0.0.1"}, state) do
    Logger.error("EDS connection lost. Aborting.")
    Logger.flush()
    System.halt()

    {:noreply, state}
  end

  @impl true
  def handle_info(_message, state), do: {:noreply, state}
end
