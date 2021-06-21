defmodule EDSWeb.Router do
  use EDSWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", EDSWeb do
    pipe_through :api
  end
end
