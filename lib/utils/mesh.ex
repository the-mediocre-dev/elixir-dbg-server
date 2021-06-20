defmodule EDS.Utils.Mesh do
  def trace_server(node) do
    {:global, "#{Atom.to_string(node)}_trace_server"}
  end

  def spy_server(node) do
    {:global, "#{Atom.to_string(node)}_spy_server"}
  end

  def proxy(node) do
    {:global, "#{Atom.to_string(node)}_proxy"}
  end

  def remote_proxy(node) do
    {:global, "#{Atom.to_string(node)}_remote_proxy"}
  end
end
