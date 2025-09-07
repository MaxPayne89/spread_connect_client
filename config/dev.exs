import Config

# Development environment configuration
# Sensitive values (API keys) are configured in config/runtime.exs
# using environment variables to keep them secure.

# Note: API credentials and base URL are now loaded from environment
# variables in config/runtime.exs. See CLAUDE.md for setup instructions.

# Logging configuration for development
config :logger, :console,
  level: :debug,
  format: "[$level] $message $metadata\n",
  metadata: [:file_path, :order_index, :error_type, :error_status]

config :logger,
  level: :debug