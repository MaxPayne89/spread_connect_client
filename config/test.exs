import Config

# Test environment configuration
# Uses safe/fake credentials that don't make real API calls

# Note: Test configuration is also handled in config/runtime.exs
# These values are overridden by runtime.exs for the test environment
# with the same safe defaults to ensure consistent test behavior.

config :spread_connect_client,
  # Localhost endpoint for test mocking
  base_url: "http://localhost:4001",
  # Fake API key - safe for testing, won't create real orders
  access_token: "fake-test-token-not-real",
  # Fast timeouts and minimal retries for test performance
  pool_timeout: 500,
  receive_timeout: 1_000,
  max_retries: 0

# Logging configuration for test environment
# Reduced verbosity to minimize test output noise
config :logger, :console,
  level: :warning,
  format: "[$level] $message\n"

config :logger,
  level: :warning