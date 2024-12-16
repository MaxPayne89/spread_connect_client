defmodule SpreadConnectClient.Client.SpreadConnectClient do
  @moduledoc """
  Client for interacting with the SpreadConnect API.
  """
  alias SpreadConnectClient.Client.JsonKeys

  # @access_token "e26b5dad-44b4-4d31-8f58-30b4118b943b"
  @access_token "e26b5dad-44b4-4d31-8f58-30b4118b943c"

  @default_url "https://api.spreadconnect.app"

  @doc """
  Creates an order in SpreadConnect.

  ## Parameters
    * order_data - Map containing the order data
    * base_url - Optional base URL for the API (useful for testing)

  ## Returns
    * `{:ok, response}` on successful creation
    * `{:error, response}` on failure
  """
  @spec create_order(map(), String.t()) :: {:ok, map()} | {:error, map()}
  def create_order(order_data, base_url \\ @default_url) do
    url = "#{base_url}/orders"
    camelized_order_data = JsonKeys.camelize(order_data)

    case Req.post(url,
           headers: [{"X-SPOD-ACCESS-TOKEN", @access_token}],
           json: camelized_order_data
         ) do
      {:ok, %Req.Response{status: status, body: body}} when status in 100..399 ->
        {:ok, %{status: status, body: Jason.decode!(body)}}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, %{status: status, body: Jason.decode!(body)}}

      {:error, exception} ->
        {:error, exception}
    end
  end
end
