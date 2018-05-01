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
  instance_default: {:rand, 45, 85},
  instance_monitor: 2,
  instance_dead: {:hour, 72}

import_config "prod.secret.exs"
