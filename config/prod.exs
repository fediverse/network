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

import_config "prod.secret.exs"
