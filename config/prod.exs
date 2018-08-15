use Mix.Config

config :fd, FdWeb.Endpoint,
  server: true,
  http: [ip: {192,168,1,12}, port: 4000],
  url: [host: "fediverse.network", port: 443, scheme: "https"],
  cache_static_manifest: "priv/static/cache_manifest.json"

config :logger, level: :info

config :fd, :instances,
  autostart: true,
  readrepair: false

config :fd, :delays,
  instance_default: {:rand, 25, 35},
  instance_calm: {:hour, 12},
  instance_monitor: 1,
  instance_monitor_calm: 15,
  instance_dead: {:hour, 336}

config :sentry,
  dsn: "https://public_key@app.getsentry.com/1",
  environment_name: :prod,
  included_environments: [:prod],
  enable_source_code_context: true,
  root_source_code_path: File.cwd!,
  tags: %{
    env: "production"
  }

import_config "prod.secret.exs"
