import Config

config :spread_connect_client,
  base_url: "https://api.spreadconnect.app",
  access_token: System.get_env("SPREAD_CONNECT_ACCESS_TOKEN") || raise "Missing SPREAD_CONNECT_ACCESS_TOKEN"