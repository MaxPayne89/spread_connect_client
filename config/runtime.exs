import Config

# Runtime configuration for environment-specific settings
# This file is executed when the application starts, allowing
# environment variables to be read at runtime rather than compile time.

# Get the current Mix environment
env = config_env()

# Configure SpreadConnect client based on environment
case env do
  :test ->
    # Test environment uses safe defaults for CI/testing
    # No environment variables required
    config :spread_connect_client,
      base_url: "http://localhost:4001",
      access_token: "e26b5dad-44b4-4d31-8f58-30b4118b943b"

  _ ->
    # Development and production environments require real API credentials
    access_token = System.get_env("SPREAD_CONNECT_ACCESS_TOKEN")
    
    if is_nil(access_token) do
      raise """
      Environment variable SPREAD_CONNECT_ACCESS_TOKEN is required but not set.
      
      To set it:
        export SPREAD_CONNECT_ACCESS_TOKEN="your-api-key-here"
      
      Or create a .env file and source it:
        echo 'export SPREAD_CONNECT_ACCESS_TOKEN="your-api-key-here"' >> .env
        source .env
      """
    end
    
    # Allow base URL override via environment variable
    base_url = System.get_env("SPREAD_CONNECT_BASE_URL", "https://api.spreadconnect.app")
    
    config :spread_connect_client,
      base_url: base_url,
      access_token: access_token
end