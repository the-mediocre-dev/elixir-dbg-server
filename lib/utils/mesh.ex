defmodule EDS.Utils.Mesh do
  def trace_server(node) do
    {:global, "#{Atom.to_string(node)}_trace_server"}
  end

  def trace_proxy(node) do
    {:global, "#{Atom.to_string(node)}_trace_proxy"}
  end
end
