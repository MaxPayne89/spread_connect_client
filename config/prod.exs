import Config

# Production environment configuration
# All sensitive configuration is handled via environment variables
# in config/runtime.exs for security.

# Logging configuration for production
# Info level provides good balance of information without excessive verbosity
config :logger, :console,
  level: :info,
  format: "$time $level $message $metadata\n",
  metadata: [:file_path, :successful_count, :failed_count, :error_type]

config :logger,
  level: :info