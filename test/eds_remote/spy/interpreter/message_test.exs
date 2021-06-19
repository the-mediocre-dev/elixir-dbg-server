defmodule EDS.Remote.Spy.Interpreter.MessageTests do
  use EDS.DataCase, async: false

  alias EDS.Remote.Spy.Server
  alias EDS.Fixtures.Messages

  setup_all do
    start_supervised(Server)
    Server.load(Messages)
    start_supervised(Messages)
    :ok
  end

  setup do
    [self: self()]
  end

  test "send/recieve", %{self: self} do
    send(Messages, {:test_recieve, self})
    assert_receive {:test_recieved, ^self}, 100
  end

  test "send/recieve to self", %{self: self} do
    send(Messages, {:test_self_recieve, self})
    assert_receive {:test_self_recieved, ^self}, 100
  end

  test "timeout", %{self: self} do
    send(Messages, {:test_timeout, self, 10})
    assert_receive {:test_timeout_timed_out, ^self}, 100
    refute_receive {:test_timeout_received, ^self}, 100

    send(Messages, :noop)
    send(Messages, {:test_timeout, self, 10})
    refute_receive {:test_timeout_timed_out, ^self}, 100
    assert_receive {:test_timeout_received, ^self}, 100

    send(Messages, :noop)
    send(Messages, {:test_timeout, self, 0})
    refute_receive {:test_timeout_timed_out, ^self}, 100
    assert_receive {:test_timeout_received, ^self}, 100
  end
end
