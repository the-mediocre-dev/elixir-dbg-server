# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :eds,
  dispatcher: EDS.Dispatcher,
  socket: EDS.Socket,
  spy_stack_depth: 50

# Configures the endpoint
config :eds, EDSWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "eoclt++ngNzvKpu+/gUTm6HfgakvsNTriaerS4WIwmB2ts7zaNmcgPfDZtEGh9yp",
  render_errors: [view: EDSWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: EDS.PubSub,
  live_view: [signing_salt: "KXwmjuVy"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
