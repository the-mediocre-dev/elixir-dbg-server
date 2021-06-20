defmodule EDS.Remote.Spy.Server.State do
  defstruct db: nil, processes: []
end

defmodule EDS.Remote.Spy.Server do
  use GenServer

  alias EDS.Utils.Mesh

  alias EDS.Remote.Spy.{
    Meta,
    Server.State
  }

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: Mesh.spy_server(Node.self()))
  end

  @impl true
  def init(_args) do
    {:ok,
     %State{
       db: :ets.new(__MODULE__, [:ordered_set, :protected]),
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
    GenServer.call(Mesh.spy_server(Node.self()), {:load, module})
  end

  def register_meta(module, meta) do
    GenServer.call(Mesh.spy_server(Node.self()), {:register_meta, module, meta})
  end

  def sync() do

  end

  @impl true
  def handle_call({:load, module}, _from, %{db: db} = state) do
    module_db = :ets.new(module, [:ordered_set, :public])

    module_dbs =
      db
      |> :ets.lookup({module, :refs})
      |> case do
        [] -> [module_db]
        [{{_module, :refs}, tail}] -> [module_db | tail]
      end

    :ets.insert(db, {{module, :refs}, module_dbs})
    :ets.insert(db, {module_db, []})

    case fetch_module_data(module) do
      {:ok, source, bin} ->
        :code.purge(module)
        :erts_debug.breakpoint({module, :_, :_}, false)
        {:ok, _module} = :dbg_iload.load_mod(module, source, bin, module_db)
        :erts_debug.breakpoint({module, :_, :_}, true)

        {:reply, {:ok, module}, state}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:get_meta, host, mfa}, _from, state) do
    state
    |> find_process(:host, host)
    |> case do
      nil ->
        meta =
          Kernel.spawn(fn ->
            Meta.start(host, mfa)
          end)

        {:reply, {:ok, meta}, add_process(state, host, meta)}

      %{meta: meta} ->
        send(meta, {:re_entry, host, {:eval, mfa}})

        {:reply, {:ok, meta}, state}
    end
  end

  @impl true
  def handle_call({:fetch_module_db, module}, _from, state) do
    case :ets.lookup(state.db, {module, :refs}) do
      [{{_module, :refs}, [module_db | _]}] ->
        {:reply, module_db, state}

      _else ->
        {:reply, :not_found, state}
    end
  end

  @impl true
  def handle_call({:register_meta, module, meta}, _from, state) do
    with [{{_module, :refs}, [module_db | _]}] <- :ets.lookup(state.db, {module, :refs}),
         [{module_db, pids}] <- :ets.lookup(state.db, module_db) do
      :ets.insert(state.db, {module_db, [meta | pids]})
      {:reply, :ok, state}
    else
      _ -> raise "Registering meta process failed"
    end
  end

  defp fetch_module_data(module) do
    with {:module, _module} <- Code.ensure_loaded(module),
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
end
