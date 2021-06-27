defmodule EDS.Remote.Spy.Server.State do
  defstruct code_db: nil, spy_db: nil, processes: []
end

defmodule EDS.Remote.Spy.Server do
  use GenServer

  alias EDS.Utils.{Code, Mesh}

  alias EDS.Remote.Spy.{
    Meta,
    Server.State
  }

  @spy_stack_depth Application.get_env(:eds, :spy_stack_depth)

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: Mesh.spy_server(Node.self()))
  end

  @impl true
  def init(_args) do
    {:ok,
     %State{
       code_db: :ets.new(__MODULE__, [:ordered_set, :protected]),
       spy_db: :ets.new(__MODULE__, [:bag, :protected]),
       processes: []
     }}
  end

  def fetch_module_db(module) do
    GenServer.call(Mesh.spy_server(Node.self()), {:fetch_module_db, module})
  end

  def get_meta!(mfa) do
    case GenServer.call(Mesh.spy_server(Node.self()), {:get_meta, self(), mfa}) do
      {:ok, meta} ->
        meta

      _else ->
        raise "Failed to find meta process"
    end
  end

  def load(module) do
    Node.self()
    |> Mesh.spy_server()
    |> GenServer.call({:load, module})
  end

  def register_meta(module, meta) do
    Node.self()
    |> Mesh.spy_server()
    |> GenServer.call({:register_meta, module, meta})
  end

  def spy_function(status) do
    Node.self()
    |> Mesh.spy_server()
    |> GenServer.cast({:spy_function, self(), status})
  end

  def spy_expr(line, bindings) do
    Node.self()
    |> Mesh.spy_server()
    |> GenServer.cast({:spy_expr, self(), line, bindings})
  end

  @impl true
  def handle_call({:insert, mfas_or_mls}, _pid, %{code_db: code_db, spy_db: spy_db} = state) do
    for mfa_or_ml <- mfas_or_mls, do: insert_spy(mfa_or_ml, code_db, spy_db)

    {:reply, :ok, state}
  end

  def handle_call({:delete, mfas_or_mls}, _pid, %{spy_db: spy_db} = state) do
    for mfa_or_ml <- mfas_or_mls, do: delete_spy(mfa_or_ml, spy_db)

    {:reply, :ok, state}
  end

  def handle_call({:load, module}, _from, %{code_db: code_db} = state),
    do: {:reply, load_module(module, code_db), state}

  def handle_call({:get_meta, host, mfa}, _from, state) do
    state
    |> find_process(:host, host)
    |> case do
      nil ->
        {meta, _ref} =
          Kernel.spawn_monitor(fn ->
            Meta.start(host, mfa)
          end)

        {:reply, {:ok, meta}, add_process(state, host, meta)}

      %{meta: meta} ->
        send(meta, {:re_entry, host, {:eval, mfa}})

        {:reply, {:ok, meta}, state}
    end
  end

  def handle_call({:fetch_module_db, module}, _from, state) do
    case :ets.lookup(state.code_db, {module, :refs}) do
      [{{_module, :refs}, [module_db | _]}] ->
        {:reply, module_db, state}

      _else ->
        {:reply, :not_found, state}
    end
  end

  def handle_call({:register_meta, module, meta}, _from, state) do
    with [{{_module, :refs}, [module_db | _]}] <- :ets.lookup(state.code_db, {module, :refs}),
         [{module_db, pids}] <- :ets.lookup(state.code_db, module_db) do
      :ets.insert(state.code_db, {module_db, [meta | pids]})
      {:reply, :ok, state}
    else
      _ -> raise "Registering meta process failed"
    end
  end

  @impl true
  def handle_cast({:spy_function, meta, {:entry, mfa}}, state) do
    spies =
      case :ets.lookup(state.code_db, meta) do
        [{_pid, spies}] when length(spies) >= @spy_stack_depth ->
          try_publish_mfa({List.last(spies), :entry}, state.spy_db)
          [{mfa, []} | Enum.drop(spies, -1)]

        [{_pid, spies}] ->
          [{mfa, []} | spies]

        _else ->
          [{mfa, []}]
      end

    :ets.insert(state.code_db, {meta, spies})

    {:noreply, state}
  end

  def handle_cast({:spy_function, meta, status}, state) do
    spies =
      case :ets.lookup(state.code_db, meta) do
        [{_pid, [spy | spies]}] ->
          try_publish_mfa({spy, status}, state.spy_db)
          spies

        _else ->
          []
      end

    :ets.insert(state.code_db, {meta, spies})

    {:noreply, state}
  end

  def handle_cast({:spy_expr, meta, line, bindings}, state) do
    spies =
      case :ets.lookup(state.code_db, meta) do
        [{_pid, [{{module, _, _} = mfa, []} | spies]}] ->
          try_publish_ml({{module, line}, bindings}, state.spy_db)
          [{mfa, [{line, bindings}]} | spies]

        [{_pid, [{mfa, [{^line, _bindings} | exprs]} | spies]}] ->
          [{mfa, [{line, bindings} | exprs]} | spies]

        [{_pid, [{{module, _, _} = mfa, exprs} | spies]}] ->
          try_publish_ml({{module, line}, bindings}, state.spy_db)
          [{mfa, [{line, bindings} | exprs]} | spies]

        _else ->
          []
      end

    :ets.insert(state.code_db, {meta, spies})

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, meta, _reason}, state) do
    :ets.delete(state.code_db, meta)

    {:noreply, state}
  end

  defp load_module(module, code_db) do
    case :ets.lookup(code_db, {module, :refs}) do
      [] ->
        module_db = :ets.new(module, [:ordered_set, :public])

        module_dbs =
          code_db
          |> :ets.lookup({module, :refs})
          |> case do
            [] -> [module_db]
            [{{_module, :refs}, tail}] -> [module_db | tail]
          end

        :ets.insert(code_db, {{module, :refs}, module_dbs})
        :ets.insert(code_db, {module_db, []})

        with {:ok, source, bin} <- fetch_module_data(module) do
          :code.purge(module)
          :erts_debug.breakpoint({module, :_, :_}, false)
          {:ok, _module} = :dbg_iload.load_mod(module, source, bin, module_db)
          :erts_debug.breakpoint({module, :_, :_}, true)

          {:ok, module}
        end

      _else ->
        {:ok, module}
    end
  end

  defp fetch_module_data(module) do
    with {:module, _module} <- :code.ensure_loaded(module),
         {:ok, source, source_bin, md5} <- fetch_source(module),
         {:ok, exports, ast} <- fetch_beam(module),
         bin = :erlang.term_to_binary({:interpreter_module, exports, ast, source_bin, md5}) do
      {:ok, source, bin}
    end
  end

  defp fetch_source(module) do
    source =
      module
      |> apply(:__info__, [:compile])
      |> Keyword.get(:source)

    with true <- File.regular?(source),
         md5 when is_binary(md5) <- apply(module, :__info__, [:md5]),
         {:ok, encoded_source, _path} <- :erl_prim_loader.get_file(source) do
      {:ok, source, :unicode.characters_to_binary(encoded_source), md5}
    else
      _ -> {:error, :failed_to_load_source}
    end
  end

  defp fetch_beam(module) do
    with beam when is_list(beam) <- :code.which(module),
         {:ok, {_module, [{:abstract_code, {:raw_abstract_v1, _} = ast}, {:exports, exports}]}} <-
           :beam_lib.chunks(beam, [:abstract_code, :exports]) do
      {:ok, exports, ast}
    else
      _ -> {:error, :failed_to_load_beam}
    end
  end

  def find_process(%{processes: processes}, type, pid) do
    Enum.find(processes, nil, &(Map.get(&1, type) == pid))
  end

  def add_process(%{processes: processes} = state, host, meta) do
    Map.put(state, :processes, [%{meta: meta, host: host} | processes])
  end

  defp insert_spy(mfa_or_ml, code_db, spy_db) do
    with {:ok, mfa_or_ml} <- Code.parse_mfa_or_ml(mfa_or_ml),
         {:ok, _module} <- load_module(elem(mfa_or_ml, 0), code_db) do
      :ets.insert(spy_db, mfa_or_ml)
    end
  end

  defp delete_spy(mfa_or_ml, spy_db) do
    with {:ok, mfa_or_ml} <- Code.parse_mfa_or_ml(mfa_or_ml) do
      :ets.delete_object(spy_db, mfa_or_ml)
    end
  end

  defp try_publish_mfa({{mfa, exprs}, status}, spy_db) do
    case :ets.select(spy_db, [{mfa, [], [:"$_"]}]) do
      [^mfa] -> publish_spy({{mfa, Enum.reverse(exprs)}, status})
      _else -> :noop
    end
  end

  defp try_publish_ml({ml, _epxr} = spy, spy_db) do
    case :ets.select(spy_db, [{ml, [], [:"$_"]}]) do
      [^ml] -> publish_spy(spy)
      _else -> :noop
    end
  end

  defp publish_spy(spy) do
    Node.self()
    |> Mesh.proxy()
    |> GenServer.cast({:spy_event, Node.self(), spy})
  end
end
