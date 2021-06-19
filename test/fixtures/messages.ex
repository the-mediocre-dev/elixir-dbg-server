defmodule EDS.Fixtures.Messages do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(state) do
    {:ok, state, {:continue, :message_loop}}
  end

  def handle_continue(:message_loop, state) do
    message_loop(state)
  end

  defp message_loop(state) do
    receive do
      {:test_recieve, pid} ->
        send_message(pid, {:test_recieved, pid}, state)

      {:test_self_recieve, pid} ->
        send_message(self(), {:test_self_recieved, pid}, state)

      {:test_self_recieved, pid} ->
        send_message(pid, {:test_self_recieved, pid}, state)

      {:test_timeout, pid, timeout} ->
        receive do
          _ ->
            send_message(pid, {:test_timeout_received, pid}, state)
        after
          timeout ->
            send_message(pid, {:test_timeout_timed_out, pid}, state)
        end
    end
  end

  defp send_message(pid, message, state) do
    send(pid, message)
    message_loop(state)
  end
end
