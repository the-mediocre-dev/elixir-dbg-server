defmodule EDS.Dispatcher do
  use GenServer

  require Logger

  alias EDS.Repo

  @socket Application.get_env(:eds, :socket)

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  def client_status(client, status) do
    GenServer.call(__MODULE__, {:client_status, client, status})
  end

  def node_status(node, status) do
    GenServer.call(__MODULE__, {:node_status, node, status})
  end

  def trace_event(node, mfa, response) do
    GenServer.call(__MODULE__, {:trace_event, node, mfa, response})
  end

  def spy_event(node, mfa, spy, status) do
    GenServer.call(__MODULE__, {:spy_event, node, mfa, spy, status})
  end

  def spy_event(node, ml, spy) do
    GenServer.call(__MODULE__, {:spy_event, node, ml, spy})
  end

  @impl true
  def handle_call({:client_status, client, :up}, _pid, state) do
    Repo.insert_client(client)

    Logger.info("client up: #{client}")

    {:reply, :ok, state}
  end

  def handle_call({:client_status, client, :down}, _pid, state) do
    Repo.delete_client(client)

    Logger.info("client down: #{client}")

    {:reply, :ok, state}
  end

  def handle_call({:node_status, node, status}, _pid, state) do
    Repo.upsert_node(node, status)

    for client <- Repo.fetch_clients(),
        do: @socket.push(client, %{node: node, status: status})

    Logger.info("node status: #{node} #{status}")

    {:reply, :ok, state}
  end

  def handle_call({:trace_event, node, mfa, response}, _pid, state) do
    for client <- Repo.fetch_subscribed_clients(node, :trace, mfa),
        do: @socket.push(client, trace_term(node, mfa, response))

    {:reply, :ok, state}
  end

  def handle_call({:spy_event, node, mfa, expr, status}, _pid, state) do
    for client <- Repo.fetch_subscribed_clients(node, :spy, mfa),
        do: @socket.push(client, spy_term(node, mfa, expr, status))

    {:reply, :ok, state}
  end

  def handle_call({:spy_event, node, ml, expr}, _pid, state) do
    for client <- Repo.fetch_subscribed_clients(node, :spy, ml),
        do: @socket.push(client, spy_term(node, ml, expr))

    {:reply, :ok, state}
  end

  defp trace_term(node, mfa, response) do
    %{
      event: :trace,
      node: node,
      mfa: mfa,
      response: response
    }
  end

  def spy_term(node, mfa, exprs, status) do
    %{
      event: :spy,
      node: node,
      mfa: mfa,
      exprs: exprs,
      status: status
    }
  end

  def spy_term(node, ml, expr) do
    %{
      event: :spy,
      node: node,
      ml: ml,
      expr: expr
    }
  end
end
