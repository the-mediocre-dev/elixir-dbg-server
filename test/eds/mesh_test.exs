defmodule EDS.MeshTests do
  use EDS.DataCase, async: false

  alias EDS.{
    Fixtures.Remote,
    Repo,
    Utils.Mesh
  }

  @expected_expr [
    {26, [_a@1: 10]},
    {27, [_b@1: 10, _a@1: 10]},
    {28, [_c@1: 100, _b@1: 10, _a@1: 10]},
    {29, [_c@1: 100, _b@1: 10, _a@1: 10]}
  ]

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

    cast_proxy(node, :trace, :insert, "List/first/1")

    :rpc.call(node, List, :first, [[:a]])

    assert_receive {:trace_event, ^node, "List/first/1", :a}, 1_000

    cast_proxy(node, :trace, :delete, "List/first/1")

    refute_receive {:trace_event, ^node, "List/first/1", :a}, 1_000

    stop_slave(node)
  end

  test "mangled traces" do
    node = start_slave()

    cast_proxy(node, :trace, :insert, "INVALID_MFA")

    cast_proxy(node, :trace, :insert, "List/first/1")

    :rpc.call(node, List, :first, [[:a]])

    assert_receive {:trace_event, ^node, "List/first/1", :a}, 1_000

    stop_slave(node)
  end

  test "initial spies" do
    node_name = node_name()

    Repo.insert("client", :"#{node_name}@127.0.0.1", :spy, "EDS.Fixtures.Remote/27")
    Repo.insert("client", :"#{node_name}@127.0.0.1", :spy, "EDS.Fixtures.Remote/call_remote_function/0")

    node = start_slave(node_name)

    :rpc.call(node, Remote, :call_remote_function, [])

    assert_receive {:spy_event, ^node, "EDS.Fixtures.Remote/27", [_b@1: 10, _a@1: 10]}, 1_000
    assert_receive {:spy_event, ^node, "EDS.Fixtures.Remote/call_remote_function/0", @expected_expr, :exit}

    stop_slave(node)
  end

  test "add/remove spies" do
    node = start_slave()

    :rpc.call(node, Remote, :call_remote_function, [])

    refute_receive {:spy_event, ^node, "EDS.Fixtures.Remote/" <> _, _}, 1_000

    cast_proxy(node, :spy, :insert, "EDS.Fixtures.Remote/27")

    cast_proxy(node, :spy, :insert, "EDS.Fixtures.Remote/call_remote_function/0")

    :rpc.call(node, Remote, :call_remote_function, [])

    assert_receive {:spy_event, ^node, "EDS.Fixtures.Remote/27", [_b@1: 10, _a@1: 10]}, 1_000

    assert_receive {:spy_event, ^node, "EDS.Fixtures.Remote/call_remote_function/0", @expected_expr, :exit}

    cast_proxy(node, :spy, :delete, "EDS.Fixtures.Remote/27")

    cast_proxy(node, :spy, :delete, "EDS.Fixtures.Remote/call_remote_function/0")

    :rpc.call(node, Remote, :call_remote_function, [])

    refute_receive {:spy_event, ^node, "EDS.Fixtures.Remote/" <> _, _}, 1_000

    stop_slave(node)
  end

  test "spy stack depth" do
    node = start_slave()

    cast_proxy(node, :spy, :insert, "EDS.Fixtures.Remote/recursive_function/1")

    assert :rpc.call(node, Remote, :recursive_function, [5])

    assert_receive {:spy_event, ^node, "EDS.Fixtures.Remote/recursive_function/1", _, :entry}, 1_000

    for _ <- 0..4 do
      assert_receive {:spy_event, ^node, "EDS.Fixtures.Remote/recursive_function/1", _, :exit}, 1_000
    end

    refute_receive {:spy_event, ^node, "EDS.Fixtures.Remote/" <> _, _}, 1_000

    stop_slave(node)
  end

  test "spy exception" do
    node = start_slave()

    # insert spy to interpreted fixture to load the module
    cast_proxy(node, :spy, :insert, "EDS.Fixtures.Remote.Interpreted/function_call/0")
    cast_proxy(node, :spy, :insert, "EDS.Fixtures.Remote/noninterpreted_exception/0")
    cast_proxy(node, :spy, :insert, "EDS.Fixtures.Remote/interpreted_exception/0")

    assert {_, {_, {error, stacktrace}}} = :rpc.call(node, Remote, :noninterpreted_exception, [])
    assert %RuntimeError{message: "error"} = error
    assert [{EDS.Fixtures.Remote.NonInterpreted, :raise_exception, 0, [file: _, line: 14]} | _] = stacktrace

    assert {_, {_, {error, stacktrace}}} = :rpc.call(node, Remote, :interpreted_exception, [])
    assert %RuntimeError{message: "error"} = error
    assert [{EDS.Fixtures.Remote.Interpreted, :raise_exception, 0, [file: _, line: 18]} | _] = stacktrace

    assert_receive {:spy_event, ^node, "EDS.Fixtures.Remote/noninterpreted_exception/0", _, {:exception, {class, reason, stacktrace}}}, 1_000
    assert :error == class
    assert  %RuntimeError{message: "error"} == reason
    assert [{EDS.Fixtures.Remote.NonInterpreted, :raise_exception, 0, [file: _, line: 14]} | _] = stacktrace

    assert_receive {:spy_event, ^node, "EDS.Fixtures.Remote/interpreted_exception/0", _, {:exception, {class, reason, stacktrace}}}, 1_000
    assert :error == class
    assert  %RuntimeError{message: "error"} == reason
    assert [{EDS.Fixtures.Remote.Interpreted, :raise_exception, 0, [file: _, line: 18]} | _] = stacktrace

    stop_slave(node)
  end

  test "mangled spies" do
    node = start_slave()

    cast_proxy(node, :spy, :insert, "INVALID_MFA")
    cast_proxy(node, :spy, :insert, "EDS.Fixtures.Remote/call_remote_function/0")

    :rpc.call(node, Remote, :call_remote_function, [])

    assert_receive {:spy_event, ^node, "EDS.Fixtures.Remote/call_remote_function/0", @expected_expr, :exit}

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

  defp cast_proxy(node, debug, action, mfa) do
    node
    |> Mesh.proxy()
    |> GenServer.call({debug, action, mfa})
  end
end
