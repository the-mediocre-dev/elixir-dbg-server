defmodule EDSWeb.Socket do
  @behaviour Phoenix.Socket.Transport

  alias EDS.Repo

  def child_spec(_opts) do
    %{
      id: EDSWeb.Socket,
      start: {Task, :start_link, [fn -> :ok end]},
      restart: :transient
    }
  end

  def push(client, term) do
    Registry.dispatch(EDS.Registry, client, &for({pid, _} <- &1, do: send(pid, term)))
  end

  def connect(%{params: %{"client" => client}}) do
    {:ok, %{client: client}}
  end

  def connect(_), do: {:error, :invalid_connection}

  def init(%{client: client} = state) do
    Registry.register(EDS.Registry, client, {})

    {:ok, state}
  end

  def handle_control({_message, [opcode: :ping]}, state) do
    {:reply, :ok, :pong, state}
  end

  def handle_in({text, [opcode: :text]}, %{client: client} = state) do
    with {:ok, %{op: op, command: command, mfa: mfa}} <- Jason.decode(text, keys: :atoms!),
         true <- op in ["insert", "delete"],
         true <- command in ["trace", "spy"] do
      apply(Repo, String.to_existing_atom(op), [client, String.to_atom(command), mfa])
    end

    {:push, {:text, Jason.encode!(%{status: "success"})}, state}
  end

  def handle_in(_message, state), do: {:ok, state}

  def handle_info(message, state) do
    {:push, {:text, Jason.encode!(message)}, state}
  end

  def terminate(_reason, _state) do
    :ok
  end
end
