defmodule EDSWeb.ChannelCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ChannelTest
      import EDSWeb.ChannelCase

      @endpoint EDSWeb.Endpoint
    end
  end

  setup _tags do
    :ok
  end
end
