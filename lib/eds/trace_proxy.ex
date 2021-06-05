defmodule EDS.TraceProxy do
  use GenServer

  alias EDS.Utils.Mesh

  def start_link([node: node] = args) do
    GenServer.start_link(__MODULE__, args, name: Mesh.trace_proxy(node))
  end

  @impl true
  def init([node: node] = state) do
    Enum.each(EDS.Remote.Application.modules(), fn module ->
      {mod, bin, fun} = :code.get_object_code(module)

      Node.spawn_link(node, :code, :load_binary, [mod, fun, bin])
    end)

    Node.spawn_link(node, EDS.Remote.Application, :bootstrap, [])

    {:ok, state}
  end

  @impl true
  def handle_cast({:sync_request, _}, [node: node] = state) do
    node
    |> Mesh.trace_server()
    |> GenServer.cast({:sync, []})

    {:noreply, state}
  end
end
