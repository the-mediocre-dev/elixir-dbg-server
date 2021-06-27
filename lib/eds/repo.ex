defmodule EDS.Repo do
  def debugged_mfas(node, command) do
    __MODULE__
    |> :ets.select([{{:_, node, command, :"$1"}, [], [:"$1"]}])
    |> Enum.uniq()
  end

  def delete_client(client) do
    :ets.delete_object(__MODULE__, {:clients, client})
  end

  def delete_mfa(client, node, command, mfa) do
    :ets.delete_object(__MODULE__, {client, node, command, mfa})
  end

  def fetch_clients() do
    :ets.select(__MODULE__, [{{:clients, :"$1"}, [], [:"$1"]}])
  end

  def fetch_mfas(client, node, command) do
    :ets.select(__MODULE__, [{{client, node, command, :"$1"}, [], [:"$1"]}])
  end

  def fetch_node(node) do
    :ets.select(__MODULE__, [{{node, :"$1"}, [], [:"$_"]}])
  end

  def fetch_nodes() do
    match_spec =
      for status <- [:up, :ready, :down] do
        {{:_, status}, [], [:"$_"]}
      end

    :ets.select(__MODULE__, match_spec)
  end

  def fetch_subscribed_clients(node, command, mfa) do
    :ets.select(__MODULE__, [{{:"$1", node, command, mfa}, [], [:"$1"]}])
  end

  def insert_client(client) do
    :ets.insert(__MODULE__, {:clients, client})
  end

  def upsert_node(node, status) do
    :ets.delete(__MODULE__, node)
    :ets.insert(__MODULE__, {node, status})
  end

  def insert_mfa(client, node, command, mfa) do
    :ets.insert(__MODULE__, {client, node, command, mfa})
  end
end
