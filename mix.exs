defmodule EDS.MixProject do
  use Mix.Project

  def project do
    [
      app: :eds,
      version: "0.1.0",
      elixir: "~> 1.9",
      erlc_paths: elixirc_paths(Mix.env()),
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      xref: [exclude: [:dbg_iload]]
    ]
  end

  def application do
    [
      mod: {EDS.Application, []},
      extra_applications: extra_applications(Mix.env())
    ]
  end

  def extra_applications(:test), do: [:logger, :runtime_tools, :debugger]

  def extra_applications(_), do: [:logger, :runtime_tools]

  defp elixirc_paths(:test), do: ["lib", "test/support", "test/fixtures"]

  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.5.9"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:meta, "~> 0.1.3"},
      {:gun, "2.0.0-rc.2", only: :test}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"]
    ]
  end
end
