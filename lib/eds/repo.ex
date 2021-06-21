defmodule EDS.Repo do
  def insert(client, command, mfa) do
    :ets.insert(__MODULE__, {client, command, mfa})
  end

  def delete(client, command, mfa) do
    :ets.delete_object(__MODULE__, {client, command, mfa})
  end

  def query(client, command, mfa) do
    __MODULE__
    |> :ets.select([{{client, command, :"$1"}, [], [:"$1"]}])
    |> Enum.member?(mfa)
  end
end
