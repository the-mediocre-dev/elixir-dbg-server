defmodule EDSWeb.TestClient do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    {:ok, %{clients: %{}}}
  end

  def connect(client) do
    GenServer.call(__MODULE__, {:connect, client})
  end

  def command(client, node, op, command, mfa) do
    GenServer.call(__MODULE__, {:command, {client, node, op, command, mfa}})
  end

  def ping(client) do
    GenServer.call(__MODULE__, {:ping, client})
  end

  @impl true
  def handle_call({:command, {client, node, op, command, mfa}}, _, %{clients: clients} = state) do
    payload = Jason.encode!(%{op: op, node: node, command: command, mfa: mfa})

    :gun.ws_send(clients[client].gun, clients[client].stream, {:text, payload})

    {:reply, :ok, state}
  end

  def handle_call({:connect, client}, {pid, _ref}, %{clients: clients}) do
    with {:ok, gun} <- :gun.open('localhost', get_port_config(), %{protocols: [:http]}),
         {:ok, _protocol} <- :gun.await_up(gun) do
      stream = :gun.ws_upgrade(gun, '/ws/trace?client=#{client}', [], %{silence_pings: false})

      receive do
        {:gun_upgrade, _gun, _stream, ["websocket"], _headers} ->
          {:reply, :ok,
           %{
             clients:
               clients
               |> Map.put(stream, %{pid: pid, gun: gun, client: client})
               |> Map.put(client, %{stream: stream, gun: gun})
           }}
      after
        1000 ->
          exit(:timeout)
      end
    end
  end

  def handle_call({:ping, client}, _, %{clients: clients} = state) do
    :gun.ws_send(clients[client].gun, clients[client].stream, :ping)

    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:gun_ws, _gun, stream, {:text, data}}, %{clients: clients} = state) do
    case Jason.decode(data) do
      {:ok, decoded} ->
        send(clients[stream].pid, {clients[stream].client, decoded})

      _else ->
        send(clients[stream].pid, {clients[stream].client, data})
    end

    {:noreply, state}
  end

  def handle_info({:gun_ws, _gun, stream, :pong}, %{clients: clients} = state) do
    send(clients[stream].pid, {clients[stream].client, :pong})

    {:noreply, state}
  end

  defp get_port_config() do
    :eds
    |> Application.get_env(EDSWeb.Endpoint)
    |> Keyword.get(:http)
    |> Keyword.get(:port)
  end
end
