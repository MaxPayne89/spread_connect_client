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
  access_token: "e26b5dad-44b4-4d31-8f58-30b4118b943b"