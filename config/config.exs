# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :fd,
  ecto_repos: [Fd.Repo]

# Configures the endpoint
config :fd, FdWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "UknRWRgXICA0mCWa7QeT/M5pUPZoyZfUmdIsdSbCEh2ObH4mGcwxXwEqR5IgDJYp",
  render_errors: [view: FdWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Fd.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :fd, :instances,
  autostart: false,
  readrepair: false

config :fd, :delays,
  instance_default: {:rand, 45, 85},
  instance_monitor: 2,
  instance_dead: {:hour, 72}

config :phoenix, :template_engines,
  md: PhoenixMarkdown.Engine

config :phoenix_markdown, :earmark, %{
  gfm: true,
  breaks: true
}
config :phoenix_markdown, :server_tags, :all

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
