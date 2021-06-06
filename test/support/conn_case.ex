defmodule EDSWeb.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      import EDSWeb.ConnCase

      alias EDSWeb.Router.Helpers, as: Routes

      @endpoint EDSWeb.Endpoint
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
