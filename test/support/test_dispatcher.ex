defmodule EDS.TestDispatcher do
  use GenServer

  def start_link(pid) do
    GenServer.start_link(__MODULE__, pid, name: __MODULE__)
  end

  @impl true
  def init(pid) do
    {:ok, pid}
  end

  def node_up(node) do
    GenServer.cast(__MODULE__, {:node_up, node})
  end

  def node_ready(node) do
    GenServer.cast(__MODULE__, {:node_ready, node})
  end

  def node_down(node) do
    GenServer.cast(__MODULE__, {:node_down, node})
  end

  def trace_event(node, mfa, response) do
    GenServer.cast(__MODULE__, {:trace_event, node, mfa, response})
  end

  def spy_event(node, mfa, spy, status) do
    GenServer.cast(__MODULE__, {:spy_event, node, mfa, spy, status})
  end

  def spy_event(node, ml, spy) do
    GenServer.cast(__MODULE__, {:spy_event, node, ml, spy})
  end

  @impl true
  def handle_cast(message, pid) do
    send(pid, message)

    {:noreply, pid}
  end
end
