defmodule EDS.DispatcherTest do
  use EDS.DataCase, async: false

  alias EDS.{Dispatcher, Repo}

  setup do
    {:ok, _pid} = start_supervised({EDS.Dispatcher, self()})
    {:ok, _pid} = start_supervised({EDS.TestSocket, self()})

    :ok
  end

  test "client attach/detach" do
    Dispatcher.client_status("client", :up)

    assert ["client"] = Repo.fetch_clients()

    Dispatcher.client_status("client", :down)

    assert [] = Repo.fetch_clients()
  end

  test "node attach/detach" do
    Dispatcher.client_status("client_1", :up)
    Dispatcher.client_status("client_2", :up)

    Dispatcher.node_status("node", :up)

    assert [{"node", :up}] = Repo.fetch_nodes()

    assert_receive {:push, "client_1", %{node: "node", status: :up}}, 1_000
    assert_receive {:push, "client_2", %{node: "node", status: :up}}, 1_000

    Dispatcher.node_status("node", :ready)

    assert [{"node", :ready}] = Repo.fetch_nodes()

    assert_receive {:push, "client_1", %{node: "node", status: :ready}}, 1_000
    assert_receive {:push, "client_2", %{node: "node", status: :ready}}, 1_000

    Dispatcher.node_status("node", :down)

    assert [{"node", :down}] = Repo.fetch_nodes()

    assert_receive {:push, "client_1", %{node: "node", status: :down}}, 1_000
    assert_receive {:push, "client_2", %{node: "node", status: :down}}, 1_000
  end

  test "trace events" do
    Dispatcher.client_status("client_1", :up)
    Dispatcher.client_status("client_2", :up)
    Dispatcher.node_status("node", :up)

    Repo.insert_mfa("client_1", "node", :trace, "Module/function/0")

    Dispatcher.trace_event("node", "Module/function/0", %{a: :a})

    assert_receive {:push, "client_1", %{response: %{a: :a}, event: :trace, mfa: "Module/function/0", node: "node"}},
                   1_000

    refute_receive {:push, "client_2", %{event: :trace}}, 1_000
  end

  test "spy events" do
    Dispatcher.client_status("client_1", :up)
    Dispatcher.client_status("client_2", :up)
    Dispatcher.node_status("node", :up)

    Repo.insert_mfa("client_1", "node", :spy, "Module/function/0")
    Repo.insert_mfa("client_1", "node", :spy, "Module/1")

    Dispatcher.spy_event("node", "Module/function/0", [_@a1: true], :exit)
    Dispatcher.spy_event("node", "Module/1", _@a1: true)

    assert_receive {:push, "client_1",
                    %{event: :spy, exprs: [_@a1: true], mfa: "Module/function/0", node: "node", status: :exit}},
                   1_000

    assert_receive {:push, "client_1", %{event: :spy, expr: [_@a1: true], ml: "Module/1", node: "node"}}, 1_000

    refute_receive {:push, "client_2", %{event: :spy}}, 1_000
  end
end
