defmodule SpreadConnectClient.MixProject do
  use Mix.Project

  def project do
    [
      app: :spread_connect_client,
      version: "0.2.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {SpreadConnectClient.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:finch, "~> 0.18"},
      {:jason, "~> 1.4"},
      {:req, "~> 0.5.0"},
      {:nimble_csv, "~> 1.2"},
      {:bypass, "~> 2.0", only: :test}
    ]
  end
end
