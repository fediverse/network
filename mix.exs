defmodule Fd.Mixfile do
  use Mix.Project

  def project do
    [
      app: :fd,
      version: "0.0.1",
      elixir: "~> 1.4",
      elixirc_paths: elixirc_paths(Mix.env),
      compilers: [:phoenix, :gettext] ++ Mix.compilers,
      start_permanent: Mix.env == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Fd.Application, []},
      extra_applications: [:logger, :runtime_tools, :earmark, :ex_shards, :ex2ms, :parse_trans]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.3.0"},
      {:phoenix_pubsub, "~> 1.0"},
      {:phoenix_ecto, "~> 3.2"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 2.10"},
      {:phoenix_live_reload, "~> 1.0", only: :dev},
      {:gettext, "~> 0.11"},
      {:cowboy, "~> 1.0"},
      {:hackney, "~> 1.12.1", override: true},
      {:httpoison, "~> 1.0", override: true},
      {:distillery, github: "bitwalker/distillery"},
      {:jason, "~> 1.0"},
      {:idna, "~> 5.1", override: true},
      {:public_suffix, "~> 0.6.0"},
      {:swoosh, "~> 0.13"},
      {:phoenix_markdown, "~> 1.0"},
      {:html_sanitize_ex, "~> 1.3.0-rc3"},
      {:timex, "~> 3.3"},
      {:earmark, "~> 1.2", runtime: true, override: true},
      {:nebulex, "~> 1.0.0-rc.3"},
      {:prometheus, "~> 4.1", override: true},
      {:prometheus_ex, "~> 3.0", override: true},
      {:prometheus_plugs, "~> 1.1.1"},
      {:prometheus_phoenix, "~> 1.0"},
      {:prometheus_ecto, "~> 1.0.3"},
      #{:prometheus_process_collector, "~> 1.0"},
      {:sentry, "~> 6.0.0"},
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "test": ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end
