defmodule EDS.Dispatcher do
  use GenServer

  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    {:ok, []}
  end

  def node_up(_node) do
  end

  def node_ready(_node) do
  end

  def node_down(_node) do
  end
end
