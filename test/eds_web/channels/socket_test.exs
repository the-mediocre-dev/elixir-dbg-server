defmodule EDSWeb.SocketTest do
  use EDS.DataCase, async: false

  alias EDS.Repo

  alias EDSWeb.{
    Socket,
    TestClient
  }

  setup do
    {:ok, _pid} = start_supervised({TestClient, []})

    :ok
  end

  test "push" do
    TestClient.connect("client_1")
    TestClient.connect("client_2")

    Socket.push("client_1", %{key: :value})

    assert_receive {"client_1", %{"key" => "value"}}, 100
    refute_receive {"client_2", %{"key" => "value"}}, 100
  end

  test "ping" do
    TestClient.connect("client_1")
    TestClient.connect("client_2")

    TestClient.ping("client_1")

    assert_receive {"client_1", :pong}, 100
    refute_receive {"client_2", :pong}, 100
  end

  test "insert/delete trace" do
    test_command("client_1", :trace, "Test/test/1")
  end

  test "insert/delete spy" do
    test_command("client_1", :spy, "Test/test/1")
  end

  defp test_command(client, command, mfa) do
    TestClient.connect(client)

    refute Repo.query(client, command, mfa)

    TestClient.command(client, :insert, command, mfa)

    assert_receive {client, %{"status" => "success"}}, 100

    assert Repo.query(client, command, mfa)

    TestClient.command(client, :delete, command, mfa)

    assert_receive {client, %{"status" => "success"}}, 100

    refute Repo.query(client, command, mfa)
  end
end
