defmodule EDS.MeshTests do
  use EDS.DataCase, async: false

  alias EDS.{
    Repo,
    Utils.Mesh
  }

  setup do
    {:ok, _pid} = start_supervised({EDS.TestDispatcher, self()})

    :ok
  end

  test "node attach/detach" do
    node = start_slave()
    assert is_pid(GenServer.whereis(Mesh.proxy(node)))

    stop_slave(node)
    refute is_pid(GenServer.whereis(Mesh.proxy(node)))
  end

  test "initial traces" do
    node_name = node_name()

    Repo.insert("client", :"#{node_name}@127.0.0.1", :trace, "List/first/1")

    node = start_slave(node_name)

    :rpc.call(node, List, :first, [[:a]])

    assert_receive {:trace_event, ^node, "List/first/1", :a}, 1_000

    stop_slave(node)
  end

  test "add/remove traces" do
    node = start_slave()

    :rpc.call(node, List, :first, [[:a]])

    refute_receive {:trace_event, ^node, "List/first/1", :a}, 1_000

    node
    |> Mesh.proxy()
    |> GenServer.call({:trace, :insert, "List/first/1"})

    :rpc.call(node, List, :first, [[:a]])

    assert_receive {:trace_event, ^node, "List/first/1", :a}, 1_000

    node
    |> Mesh.proxy()
    |> GenServer.call({:trace, :delete, "List/first/1"})

    refute_receive {:trace_event, ^node, "List/first/1", :a}, 1_000

    stop_slave(node)
  end

  defp start_slave(node_name \\ node_name()) do
    {:ok, node} = :slave.start_link('127.0.0.1', node_name)

    assert_receive {:node_up, ^node}, 5_000
    assert_receive {:node_ready, ^node}, 1_000

    node
  end

  defp stop_slave(node) do
    :slave.stop(node)

    assert_receive {:node_down, ^node}, 5_000
  end

  defp node_name() do
    for(_ <- 1..10, into: "", do: <<Enum.random('0123456789abcdef')>>) |> String.to_charlist()
  end
end
