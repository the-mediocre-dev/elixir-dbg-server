defmodule EDS.Remote.Trace.Server do
  use GenServer

  alias EDS.Utils.{Code, Mesh}

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: Mesh.trace_server(Node.self()))
  end

  @impl true
  def init(state) do
    :erlang.trace(:all, true, [:call, {:tracer, self()}])

    {:ok, state}
  end

  @impl true
  def handle_info({:trace, _, :return_from, mfa, response}, state) do
    Node.self()
    |> Mesh.proxy()
    |> GenServer.cast({:trace_event, Node.self(), {mfa, response}})

    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  @impl true
  def handle_call({:insert, traces}, _pid, state) do
    for mfa <- traces, do: insert_trace(mfa)

    {:reply, :ok, state}
  end

  def handle_call({:delete, traces}, _pid, state) do
    for trace <- traces, do: delete_trace(trace)

    {:reply, :ok, state}
  end

  def handle_call(_message, state), do: {:reply, :ok, state}

  defp insert_trace(mfa),
    do: update_trace_pattern(mfa, [{:_, [], [{:return_trace}]}])

  defp delete_trace(mfa),
    do: update_trace_pattern(mfa, false)

  defp update_trace_pattern(mfa, match_spec) do
    with {:ok, {_, _, _} = mfa} <- Code.parse_mfa_or_ml(mfa) do
      :erlang.trace_pattern(mfa, match_spec)
    end
  end
end
