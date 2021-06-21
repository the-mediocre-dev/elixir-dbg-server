defmodule EDSWeb.SocketCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Plug.Conn
    end
  end

  setup _tags do
    {:ok, []}
  end
end
