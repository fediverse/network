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
server: true,
  http: [
    protocol_options: [max_request_line_length: 8192, max_header_value_length: 8192],
    dispatch: [
      {:_, [
        {'/.well-known/[...]', Plug.Adapters.Cowboy.Handler, {Pleroma.Web.Endpoint, []}},
        {'/nodeinfo/[...]', Plug.Adapters.Cowboy.Handler, {Pleroma.Web.Endpoint, []}},
        {'/api/ostatus[...]', Plug.Adapters.Cowboy.Handler, {Pleroma.Web.Endpoint, []}},
        {'/main/ostatus/[...]', Plug.Adapters.Cowboy.Handler, {Pleroma.Web.Endpoint, []}},
        {'/objects/[...]', Plug.Adapters.Cowboy.Handler, {Pleroma.Web.Endpoint, []}},
        {'/activities/[...]', Plug.Adapters.Cowboy.Handler, {Pleroma.Web.Endpoint, []}},
        {'/notice/[...]', Plug.Adapters.Cowboy.Handler, {Pleroma.Web.Endpoint, []}},
        {'/users/[...]', Plug.Adapters.Cowboy.Handler, {Pleroma.Web.Endpoint, []}},
        {'/push/[...]', Plug.Adapters.Cowboy.Handler, {Pleroma.Web.Endpoint, []}},
        {'/relay/[...]', Plug.Adapters.Cowboy.Handler, {Pleroma.Web.Endpoint, []}},
        {'/inbox/[...]', Plug.Adapters.Cowboy.Handler, {Pleroma.Web.Endpoint, []}},
        {'/proxy/[...]', Plug.Adapters.Cowboy.Handler, {Pleroma.Web.Endpoint, []}},
        {'/media/[...]', Plug.Adapters.Cowboy.Handler, {Pleroma.Web.Endpoint, []}},
        {'/static/[...]', Plug.Adapters.Cowboy.Handler, {Pleroma.Web.Endpoint, []}},
        {'/api/v1/instance/[...]', Plug.Adapters.Cowboy.Handler, {Pleroma.Web.Endpoint, []}},
        {'/api/statusnet/config', Plug.Adapters.Cowboy.Handler, {Pleroma.Web.Endpoint, []}},
        {:_, Plug.Adapters.Cowboy.Handler, {FdWeb.Endpoint, []}}
      ]}
    ]
  ],
  secret_key_base: "UknRWRgXICA0mCWa7QeT/M5pUPZoyZfUmdIsdSbCEh2ObH4mGcwxXwEqR5IgDJYp",
  render_errors: [view: FdWeb.ErrorView, accepts: ~w(html json)],
  instrumenters: [FdWeb.PhoenixInstrumenter],
  pubsub: [name: Fd.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :fd, :admin_instances, []

config :fd, :instances,
  autostart: false,
  readrepair: false

config :fd, :delays,
  instance_default: {:rand, 25, 35},
  instance_calm: {:hour, 12},
  instance_monitor: 1,
  instance_monitor_calm: 10,
  instance_dead: {:hour, 336}

config :phoenix, :template_engines,
  md: PhoenixMarkdown.Engine

config :phoenix_markdown, :earmark, %{
  gfm: true,
  breaks: true
}
config :phoenix_markdown, :server_tags, :all

config :fd, Fd.Cache,
  adapter: Nebulex.Adapters.Local,
  gc_interval: 3600

config :fd, Fd.Repo,
  loggers: [Fd.Repo.Instrumenter, Ecto.LogEntry]

config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000 * 60 * 4,
                                 cleanup_interval_ms: 60_000 * 10]}

config :sentry,
  dsn: "https://edfc2:23fa2bf30406@sentry.localhost/42",
  environment_name: Mix.env(),
  enable_source_code_context: true,
  root_source_code_path: File.cwd!,
  tags: %{
    env: "production"
  },
  included_environments: [:prod]
# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
import_config "pleroma.exs"
