defmodule SpreadConnectClient.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Finch, name: SpreadConnectClient.Finch, pools: %{
        default: [size: 25, count: 1]
      }}
    ]

    opts = [strategy: :one_for_one, name: SpreadConnectClient.Supervisor]
    Supervisor.start_link(children, opts)
  end
end