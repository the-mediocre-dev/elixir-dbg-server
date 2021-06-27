use Mix.Config

config :eds,
  dispatcher: EDS.TestDispatcher,
  socket: EDS.TestSocket,
  spy_stack_depth: 5

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :eds, EDSWeb.Endpoint,
  http: [port: 5454],
  server: true

# Print only warnings and errors during test
config :logger, level: :warn
