defmodule EDS.Remote.Trace.Server do
  use GenServer

  alias EDS.Utils.Mesh

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
    for trace <- traces, do: insert_trace(trace)

    {:reply, :ok, state}
  end

  def handle_call({:delete, traces}, _pid, state) do
    for trace <- traces, do: delete_trace(trace)

    {:reply, :ok, state}
  end

  def handle_call(_message, state), do: {:reply, :ok, state}

  defp insert_trace(trace),
    do: update_trace_pattern(trace, [{:_, [], [{:return_trace}]}])

  defp delete_trace(trace),
    do: update_trace_pattern(trace, false)

  defp update_trace_pattern(trace, match_spec) do
    with {:ok, mfa} <- parse_mfa(trace) do
      :erlang.trace_pattern(mfa, match_spec)
    end
  end

  defp parse_mfa(trace) do
    mfa =
      with [module, function, arity] <- String.split(trace, "/"),
           module <- String.to_existing_atom(module),
           function <- String.to_existing_atom(function),
           {arity, _} <- Integer.parse(arity) do
        {Module.concat(Elixir, module), function, arity}
      end

    {:ok, mfa}
  rescue
    _ ->
      {:error, :invalid_mfa}
  end
end
