defmodule SpreadConnectClient.Client.SpreadConnectClient do
  @moduledoc """
  Documentation for `SpreadConnectClient`.
  """
  alias Req

  @access_token "e26b5dad-44b4-4d31-8f58-30b4118b943b"

  @doc """
  Creates an order in SpreadConnect.

  ## Examples

      iex> SpreadConnectClient.hello()
      :world

  """
  def create_order(order_data) do
    url = "https://api.spreadconnect.app/orders"
    headers = [{"X-SPOD-ACCESS-TOKEN", "#{@access_token}"}]
    tuple = Req.post(url, headers: headers, json: order_data)
    IO.inspect(tuple)
  end
end
