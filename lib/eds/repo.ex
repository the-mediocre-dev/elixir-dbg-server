defmodule EDS.Repo do
  def insert(client, node, command, mfa) do
    :ets.insert(__MODULE__, {client, node, command, mfa})
  end

  def delete(client, node, command, mfa) do
    :ets.delete_object(__MODULE__, {client, node, command, mfa})
  end

  def query(client, node, command, mfa) do
    __MODULE__
    |> :ets.select([{{client, node, command, :"$1"}, [], [:"$1"]}])
    |> Enum.member?(mfa)
  end
end
