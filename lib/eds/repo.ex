defmodule EDS.Repo do
  def delete(client, node, command, mfa) do
    :ets.delete_object(__MODULE__, {client, node, command, mfa})
  end

  def insert(client, node, command, mfa) do
    :ets.insert(__MODULE__, {client, node, command, mfa})
  end

  def is_debugged?(client, node, command, mfa) do
    __MODULE__
    |> :ets.select([{{client, node, command, :"$1"}, [], [:"$1"]}])
    |> Enum.member?(mfa)
  end

  def debugged_mfas(node, command) do
    __MODULE__
    |> :ets.select([{{:_, node, command, :"$1"}, [], [:"$1"]}])
    |> Enum.uniq()
  end
end
