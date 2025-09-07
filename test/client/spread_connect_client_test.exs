defmodule SpreadConnectClient.Client.SpreadConnectClientTest do
  use ExUnit.Case, async: true

  alias SpreadConnectClient.Client.SpreadConnectClient

  setup do
    bypass = Bypass.open()
    Application.put_env(:spread_connect_client, :base_url, "http://localhost:#{bypass.port}")
    # Ensure access token is set (fallback in case config loading is delayed)
    unless Application.get_env(:spread_connect_client, :access_token) do
      Application.put_env(:spread_connect_client, :access_token, "fake-test-token-not-real")
    end
    {:ok, bypass: bypass}
  end

  describe "create_order/2" do
    test "successfully creates order with 201 response", %{bypass: bypass} do
      order_data = %{
        external_order_reference: "12345",
        order_items: [%{sku: "TEST-SKU", quantity: 1}]
      }

      Bypass.expect_once(bypass, "POST", "/orders", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        request_data = Jason.decode!(body)

        assert request_data["externalOrderReference"] == "12345"
        assert [item] = request_data["orderItems"]
        assert item["sku"] == "TEST-SKU"

        assert Plug.Conn.get_req_header(conn, "x-spod-access-token") == ["fake-test-token-not-real"]

        Plug.Conn.resp(conn, 201, ~s({"id": "order-123", "status": "created"}))
      end)

      assert {:ok, response} = SpreadConnectClient.create_order(order_data)
      assert response.status == 201
      assert response.body["id"] == "order-123"
      assert response.body["status"] == "created"
    end

    test "successfully creates order with 200 response", %{bypass: bypass} do
      order_data = %{external_order_reference: "12345"}

      Bypass.expect_once(bypass, "POST", "/orders", fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"id": "order-456", "status": "updated"}))
      end)

      assert {:ok, response} = SpreadConnectClient.create_order(order_data)
      assert response.status == 200
      assert response.body["id"] == "order-456"
    end

    test "handles 401 unauthorized error", %{bypass: bypass} do
      order_data = %{external_order_reference: "12345"}

      Bypass.expect_once(bypass, "POST", "/orders", fn conn ->
        Plug.Conn.resp(conn, 401, ~s({"error": "Invalid token"}))
      end)

      assert {:error, response} = SpreadConnectClient.create_order(order_data)
      assert response.status == 401
      assert response.body["error"] == "Unauthorized access"
    end

    test "handles 422 validation error", %{bypass: bypass} do
      order_data = %{external_order_reference: "12345"}

      Bypass.expect_once(bypass, "POST", "/orders", fn conn ->
        Plug.Conn.resp(conn, 422, ~s({"error": "Invalid data", "details": "Missing SKU"}))
      end)

      assert {:error, response} = SpreadConnectClient.create_order(order_data)
      assert response.status == 422
      assert response.body["error"] == "Invalid data"
      assert response.body["details"] == "Missing SKU"
    end

    test "handles 404 not found error", %{bypass: bypass} do
      order_data = %{external_order_reference: "12345"}

      Bypass.expect_once(bypass, "POST", "/orders", fn conn ->
        Plug.Conn.resp(conn, 404, ~s({"error": "Endpoint not found"}))
      end)

      assert {:error, response} = SpreadConnectClient.create_order(order_data)
      assert response.status == 404
      assert response.body["error"] == "Endpoint not found"
    end

    test "handles 500 server error", %{bypass: bypass} do
      order_data = %{external_order_reference: "12345"}

      Bypass.expect(bypass, "POST", "/orders", fn conn ->
        Plug.Conn.resp(conn, 500, ~s({"error": "Internal server error"}))
      end)

      assert {:error, response} = SpreadConnectClient.create_order(order_data)
      assert response.status == 500
      assert response.body["error"] == "Internal server error"
    end

    test "handles invalid JSON response from success status", %{bypass: bypass} do
      order_data = %{external_order_reference: "12345"}

      Bypass.expect_once(bypass, "POST", "/orders", fn conn ->
        Plug.Conn.resp(conn, 201, "invalid json{")
      end)

      assert {:error, response} = SpreadConnectClient.create_order(order_data)
      assert response.status == 400
      assert response.body["error"] == "Invalid JSON response format"
    end

    test "handles invalid JSON response from error status", %{bypass: bypass} do
      order_data = %{external_order_reference: "12345"}

      Bypass.expect_once(bypass, "POST", "/orders", fn conn ->
        Plug.Conn.resp(conn, 422, "invalid json{")
      end)

      assert {:error, response} = SpreadConnectClient.create_order(order_data)
      assert response.status == 422
      assert response.body["error"] == "Invalid response format"
    end

    test "handles network connection errors", %{bypass: bypass} do
      order_data = %{external_order_reference: "12345"}

      Bypass.down(bypass)

      assert {:error, response} = SpreadConnectClient.create_order(order_data)
      assert response.status == 500
      assert is_binary(response.body["error"])
    end

    test "uses custom base URL when provided", %{bypass: _bypass} do
      custom_bypass = Bypass.open()
      custom_url = "http://localhost:#{custom_bypass.port}"
      order_data = %{external_order_reference: "12345"}

      Bypass.expect_once(custom_bypass, "POST", "/orders", fn conn ->
        Plug.Conn.resp(conn, 201, ~s({"id": "custom-order"}))
      end)

      assert {:ok, response} = SpreadConnectClient.create_order(order_data, custom_url)
      assert response.body["id"] == "custom-order"

      Bypass.down(custom_bypass)
    end

    test "transforms snake_case keys to camelCase in request", %{bypass: bypass} do
      order_data = %{
        external_order_reference: "12345",
        order_items: [
          %{
            sku: "TEST-SKU",
            external_order_item_reference: "item-123",
            customer_price: %{
              amount: 19.99,
              currency: "EUR"
            }
          }
        ],
        billing_address: %{
          first_name: "John",
          last_name: "Doe",
          zip_code: "12345"
        }
      }

      Bypass.expect_once(bypass, "POST", "/orders", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        request_data = Jason.decode!(body)

        assert request_data["externalOrderReference"] == "12345"
        assert [item] = request_data["orderItems"]
        assert item["externalOrderItemReference"] == "item-123"
        assert item["customerPrice"]["amount"] == 19.99
        assert item["customerPrice"]["currency"] == "EUR"
        assert request_data["billingAddress"]["firstName"] == "John"
        assert request_data["billingAddress"]["lastName"] == "Doe"
        assert request_data["billingAddress"]["zipCode"] == "12345"

        Plug.Conn.resp(conn, 201, ~s({"id": "order-123"}))
      end)

      assert {:ok, _response} = SpreadConnectClient.create_order(order_data)
    end

    test "includes proper headers and uses Finch pool", %{bypass: bypass} do
      order_data = %{external_order_reference: "12345"}

      Bypass.expect_once(bypass, "POST", "/orders", fn conn ->
        assert Plug.Conn.get_req_header(conn, "content-type") == ["application/json"]
        assert Plug.Conn.get_req_header(conn, "x-spod-access-token") == ["fake-test-token-not-real"]

        Plug.Conn.resp(conn, 201, ~s({"id": "order-123"}))
      end)

      assert {:ok, _response} = SpreadConnectClient.create_order(order_data)
    end
  end

  describe "configuration loading" do
    test "uses default configuration values" do
      # Save original config
      original_base_url = Application.get_env(:spread_connect_client, :base_url)
      original_access_token = Application.get_env(:spread_connect_client, :access_token)
      
      # Set test config
      Application.put_env(:spread_connect_client, :base_url, "https://api.example.com")
      Application.put_env(:spread_connect_client, :access_token, "default-token")

      bypass = Bypass.open(port: 4000)

      Bypass.expect_once(bypass, "POST", "/orders", fn conn ->
        assert Plug.Conn.get_req_header(conn, "x-spod-access-token") == ["default-token"]
        Plug.Conn.resp(conn, 201, ~s({"id": "order-123"}))
      end)

      assert {:ok, _response} = SpreadConnectClient.create_order(%{}, "http://localhost:4000")

      # Cleanup
      Bypass.down(bypass)
      Application.put_env(:spread_connect_client, :base_url, original_base_url)
      Application.put_env(:spread_connect_client, :access_token, original_access_token)
    end

    test "handles missing access token gracefully" do
      Application.delete_env(:spread_connect_client, :access_token)
      bypass = Bypass.open()

      Bypass.expect_once(bypass, "POST", "/orders", fn conn ->
        headers = Plug.Conn.get_req_header(conn, "x-spod-access-token")
        assert headers == [] or headers == [""]
        Plug.Conn.resp(conn, 401, ~s({"error": "Missing token"}))
      end)

      order_data = %{external_order_reference: "12345"}
      base_url = "http://localhost:#{bypass.port}"

      assert {:error, response} = SpreadConnectClient.create_order(order_data, base_url)
      assert response.status == 401

      Bypass.down(bypass)
    end
  end
end