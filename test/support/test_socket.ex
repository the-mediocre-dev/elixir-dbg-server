defmodule EDS.TestSocket do
  use GenServer

  def start_link(pid) do
    GenServer.start_link(__MODULE__, pid, name: __MODULE__)
  end

  @impl true
  def init(pid) do
    {:ok, pid}
  end

  def push(client, term) do
    GenServer.cast(__MODULE__, {:push, client, term})
  end

  @impl true
  def handle_cast(message, pid) do
    send(pid, message)

    {:noreply, pid}
  end
end
