defmodule SpreadConnectClient.Client.SpreadConnectClient do
  @moduledoc """
  HTTP client for interacting with the SpreadConnect API.
  
  Handles order creation with proper authentication and error handling.
  Configuration is managed through Application environment settings.
  """

  alias Jason, as: JSON
  alias SpreadConnectClient.Client.JsonKeys

  @doc """
  Creates an order in SpreadConnect API.

  ## Parameters
    * `order_data` - Map containing the order data with snake_case keys
    * `base_url` - Optional override for API base URL (defaults to config value)

  ## Returns
    * `{:ok, response}` - Successful order creation with decoded response
    * `{:error, response}` - Failed request with error details

  ## Examples
      iex> SpreadConnectClient.create_order(%{external_order_reference: "12345"})
      {:ok, %{status: 201, body: %{"id" => "abc123"}}}
  """
  @spec create_order(map(), String.t() | nil) :: {:ok, map()} | {:error, map()}
  def create_order(order_data, base_url \\ nil) do
    config = load_configuration(base_url)
    transformed_data = JsonKeys.camelize(order_data)

    config.url
    |> make_api_request(config.access_token, transformed_data)
    |> handle_response()
  end

  # Private functions

  defp load_configuration(override_url) do
    %{
      url: build_api_url(override_url),
      access_token: Application.get_env(:spread_connect_client, :access_token)
    }
  end

  defp build_api_url(nil) do
    base_url = Application.get_env(:spread_connect_client, :base_url)
    "#{base_url}/orders"
  end

  defp build_api_url(override_url) do
    "#{override_url}/orders"
  end

  defp make_api_request(url, access_token, request_data) do
    pool_timeout = Application.get_env(:spread_connect_client, :pool_timeout, 5_000)
    receive_timeout = Application.get_env(:spread_connect_client, :receive_timeout, 30_000)
    max_retries = Application.get_env(:spread_connect_client, :max_retries, 2)

    Req.post(url,
      headers: [{"X-SPOD-ACCESS-TOKEN", access_token}],
      json: request_data,
      finch: SpreadConnectClient.Finch,
      pool_timeout: pool_timeout,
      receive_timeout: receive_timeout,
      retry: :transient,
      max_retries: max_retries
    )
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}}) 
       when status in 100..399 do
    case JSON.decode(body) do
      {:ok, decoded_body} -> {:ok, %{status: status, body: decoded_body}}
      {:error, _} -> {:error, build_error_response(400, "Invalid JSON response format")}
    end
  end

  defp handle_response({:ok, %Req.Response{status: 401}}) do
    {:error, build_error_response(401, "Unauthorized access")}
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}}) do
    decoded_body = decode_response_body(body)
    {:error, %{status: status, body: decoded_body}}
  end

  defp handle_response({:error, exception}) do
    {:error, build_error_response(500, Exception.message(exception))}
  end

  defp decode_response_body(body) do
    case JSON.decode(body) do
      {:ok, decoded} -> decoded
      {:error, _} -> %{"error" => "Invalid response format"}
    end
  end

  defp build_error_response(status, message) do
    %{status: status, body: %{"error" => message}}
  end
end