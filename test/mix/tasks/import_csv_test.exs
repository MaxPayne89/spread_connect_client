defmodule SpreadConnectClient.Integration.CsvImportTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Import.Csv

  setup do
    bypass = Bypass.open()
    Application.put_env(:spread_connect_client, :base_url, "http://localhost:#{bypass.port}")
    # Ensure access token is set (fallback in case config loading is delayed)
    unless Application.get_env(:spread_connect_client, :access_token) do
      Application.put_env(:spread_connect_client, :access_token, "fake-test-token-not-real")
    end
    {:ok, bypass: bypass}
  end

  describe "CSV import and API submission" do
    test "successfully processes simple CSV and submits to API", %{bypass: bypass} do
      # Setup mock API endpoint
      Bypass.expect_once(bypass, "POST", "/orders", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        order_data = JSON.decode!(body)

        # Verify the parsed data structure
        assert order_data["externalOrderReference"] == "10001"
        assert order_data["currency"] == "EUR"
        assert [order_item | _] = order_data["orderItems"]
        assert order_item["sku"] == "6739BC863E137_7907"

        # Verify headers
        assert Plug.Conn.get_req_header(conn, "x-spod-access-token") == [
                 "fake-test-token-not-real"
               ]

        Plug.Conn.resp(conn, 201, ~s({"id": "123", "status": "created"}))
      end)

      # Process the test CSV file
      result =
        "test/fixtures/single_order.csv"
        |> Csv.run()

      assert {:ok, [{:ok, {0, %{status: 201, body: %{"id" => "123", "status" => "created"}}}}]} =
               result
    end

    test "successfully processes CSV with multiple orders and submits to API", %{
      bypass: bypass
    } do
      # Setup mock API endpoint
      Bypass.expect(bypass, "POST", "/orders", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        order_data = JSON.decode!(body)

        order_reference = order_data["external_order_reference"]

        assert Plug.Conn.get_req_header(conn, "x-spod-access-token") == [
                 "fake-test-token-not-real"
               ]

        Plug.Conn.resp(conn, 201, ~s({"id": "#{order_reference}", "status": "created"}))
      end)

      # Process the test CSV file
      result =
        "test/fixtures/multiple_items.csv"
        |> Csv.run()

      assert {:ok,
              [
                {:ok, {0, %{status: 201, body: %{"status" => "created"}}}},
                {:ok, {1, %{status: 201, body: %{"status" => "created"}}}}
              ]} = result
    end

    test "handles API errors gracefully", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/orders", fn conn ->
        Plug.Conn.resp(conn, 422, ~s({"error": "Invalid data"}))
      end)

      result =
        "test/fixtures/single_order.csv"
        |> Csv.run()

      assert {:ok,
              [
                {:error, {0, %{status: 422, body: %{"error" => "Invalid data"}}}}
              ]} = result
    end
  end

  describe "CSV import error scenarios" do
    test "handles non-existent file gracefully" do
      result = Csv.run("non_existent_file.csv")

      assert {:error, reason} = result
      assert is_binary(reason)
      assert String.contains?(reason, "Failed to access file")
    end

    test "handles file without read permissions", %{bypass: _bypass} do
      # Create a temporary file and remove read permissions
      temp_file = "test/fixtures/temp_no_read.csv"
      File.write!(temp_file, "test,data\n1,2")
      File.chmod!(temp_file, 0o000)

      result = Csv.run(temp_file)

      assert {:error, reason} = result
      assert is_binary(reason)

      # Cleanup
      File.chmod!(temp_file, 0o644)
      File.rm!(temp_file)
    end

    @tag timeout: 60_000
    test "handles network timeout during API calls", %{bypass: bypass} do
      # Disconnect the bypass server to simulate network timeout
      Bypass.down(bypass)

      result = Csv.run("test/fixtures/single_order.csv")

      assert {:ok, [error_result]} = result
      assert {:error, {0, error_response}} = error_result
      assert error_response.status == 500
      assert error_response.body["error"] == "connection refused"
    end

    test "handles network connection failure", %{bypass: bypass} do
      Bypass.down(bypass)

      result = Csv.run("test/fixtures/single_order.csv")

      assert {:ok, [error_result]} = result
      assert {:error, {0, error_response}} = error_result
      assert error_response.status == 500
      assert is_binary(error_response.body["error"])
    end

    test "handles invalid CSV file format" do
      result = Csv.run("test/fixtures/invalid_format.csv")

      assert {:ok, []} = result
    end

    test "handles CSV with no Spreadconnect orders" do
      result = Csv.run("test/fixtures/insufficient_columns.csv")

      assert {:ok, []} = result
    end

    test "handles mixed success and failure in multiple orders", %{bypass: bypass} do
      {:ok, call_count} = Agent.start_link(fn -> 0 end)

      Bypass.expect(bypass, "POST", "/orders", fn conn ->
        current_count = Agent.get_and_update(call_count, fn count -> {count, count + 1} end)

        case current_count do
          0 -> 
            Plug.Conn.resp(conn, 201, ~s({"id": "success-1", "status": "created"}))
          1 -> 
            Plug.Conn.resp(conn, 422, ~s({"error": "Invalid data", "details": "Missing SKU"}))
        end
      end)

      result = Csv.run("test/fixtures/multiple_items.csv")

      assert {:ok, results} = result
      assert length(results) == 2

      # Should have one success and one failure
      successes = Enum.count(results, &match?({:ok, _}, &1))
      failures = Enum.count(results, &match?({:error, _}, &1))
      
      assert successes == 1
      assert failures == 1

      Agent.stop(call_count)
    end

    test "handles server errors (500) gracefully", %{bypass: bypass} do
      Bypass.expect(bypass, "POST", "/orders", fn conn ->
        Plug.Conn.resp(conn, 500, ~s({"error": "Internal server error"}))
      end)

      result = Csv.run("test/fixtures/single_order.csv")

      assert {:ok, [error_result]} = result
      assert {:error, {0, error_response}} = error_result
      assert error_response.status == 500
      assert error_response.body["error"] == "Internal server error"
    end

    test "handles authentication errors (401)", %{bypass: bypass} do
      Bypass.expect(bypass, "POST", "/orders", fn conn ->
        Plug.Conn.resp(conn, 401, ~s({"error": "Unauthorized"}))
      end)

      result = Csv.run("test/fixtures/single_order.csv")

      assert {:ok, [error_result]} = result
      assert {:error, {0, error_response}} = error_result
      assert error_response.status == 401
      assert error_response.body["error"] == "Unauthorized access"
    end

    test "handles rate limiting (429) gracefully", %{bypass: bypass} do
      Bypass.expect(bypass, "POST", "/orders", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("retry-after", "1")  # 1 second delay instead of 60
        |> Plug.Conn.resp(429, ~s({"error": "Rate limit exceeded"}))
      end)

      result = Csv.run("test/fixtures/single_order.csv")

      assert {:ok, [error_result]} = result
      assert {:error, {0, error_response}} = error_result
      assert error_response.status == 429
      assert error_response.body["error"] == "Rate limit exceeded"
    end

    test "handles invalid arguments to mix task" do
      # Test with no arguments
      result = Csv.run([])
      assert {:error, :invalid_arguments} = result

      # Test with invalid argument type
      result = Csv.run(123)
      assert {:error, :invalid_arguments} = result

      # Test with multiple arguments
      result = Csv.run(["file1.csv", "file2.csv"])
      assert {:error, :invalid_arguments} = result
    end

    test "handles large file processing with concurrent failures", %{bypass: bypass} do
      # Disconnect bypass to simulate connection failures under load
      Bypass.down(bypass)

      # Create a temporary file with multiple orders
      temp_csv_content = """
      Order number,Date created,Time,Fulfill by,Total order quantity,Contact email,Note from customer,Additional checkout info,Item,Variant,SKU,Qty,Quantity refunded,Price,Weight,Custom text,Deposit amount,Delivery method,Delivery time,Recipient name,Recipient phone,Recipient company name,Delivery country,Delivery state,Delivery state name,Delivery city,Delivery address,Delivery zip/postal code,Billing name,Billing phone,Billing company name,Delivery country,Delivery state,Delivery state name,Delivery city,Delivery address,Delivery zip/postal code,Payment status,Payment method,Coupon code,Gift card amount,Shipping rate,Total tax,Total,Currency,Refunded amount,Net amount,Additional fees,Fulfillment status,Tracking number,Fulfillment service,Shipping label
      "BULK001","Dec 8, 2024","9:15:51 AM","","1","test1@example.com","","","Test Item 1","","TEST-SKU-1","1","0","19.99","0","","","Standard","","John Doe 1","015224260416","Test Company","DEU","DE-BE","Berlin","Berlin","Test St 1","12345","John Doe 1","015224260416","Test Company","DEU","DE-BE","Berlin","Berlin","Test St 1","12345","Unpaid","Manual","","","0.00","0.00","19.99","EUR","0.00","19.99","0.00","Unfulfilled","","Spreadconnect","Label 1"
      "BULK002","Dec 8, 2024","9:15:51 AM","","1","test2@example.com","","","Test Item 2","","TEST-SKU-2","1","0","29.99","0","","","Standard","","John Doe 2","015224260416","Test Company","DEU","DE-BE","Berlin","Berlin","Test St 2","12345","John Doe 2","015224260416","Test Company","DEU","DE-BE","Berlin","Berlin","Test St 2","12345","Unpaid","Manual","","","0.00","0.00","29.99","EUR","0.00","29.99","0.00","Unfulfilled","","Spreadconnect","Label 2"
      "BULK003","Dec 8, 2024","9:15:51 AM","","1","test3@example.com","","","Test Item 3","","TEST-SKU-3","1","0","39.99","0","","","Standard","","John Doe 3","015224260416","Test Company","DEU","DE-BE","Berlin","Berlin","Test St 3","12345","John Doe 3","015224260416","Test Company","DEU","DE-BE","Berlin","Berlin","Test St 3","12345","Unpaid","Manual","","","0.00","0.00","39.99","EUR","0.00","39.99","0.00","Unfulfilled","","Spreadconnect","Label 3"
      """

      temp_file = "test/fixtures/temp_bulk_test.csv"
      File.write!(temp_file, temp_csv_content)

      result = Csv.run(temp_file)

      assert {:ok, results} = result
      assert length(results) == 3

      # All should fail due to connection refused
      failures = Enum.count(results, &match?({:error, _}, &1))
      assert failures == 3

      # Verify each failure is a connection error
      Enum.each(results, fn
        {:error, {_index, response}} ->
          assert response.status == 500
          assert String.contains?(response.body["error"], "connection")
        _ ->
          flunk("Expected all results to be connection errors")
      end)

      # Cleanup
      File.rm!(temp_file)
    end
  end

  describe "configuration and environment handling" do
    test "handles missing access token", %{bypass: bypass} do
      # Temporarily remove access token
      original_token = Application.get_env(:spread_connect_client, :access_token)
      Application.delete_env(:spread_connect_client, :access_token)

      Bypass.expect_once(bypass, "POST", "/orders", fn conn ->
        headers = Plug.Conn.get_req_header(conn, "x-spod-access-token")
        assert headers == [] or headers == [""]
        
        Plug.Conn.resp(conn, 401, ~s({"error": "Missing authentication"}))
      end)

      result = Csv.run("test/fixtures/single_order.csv")

      assert {:ok, [error_result]} = result
      assert {:error, {0, error_response}} = error_result
      assert error_response.status == 401

      # Restore original token
      if original_token do
        Application.put_env(:spread_connect_client, :access_token, original_token)
      end
    end

    test "uses custom base URL when provided", %{bypass: _bypass} do
      # Create a new bypass for custom URL testing
      custom_bypass = Bypass.open()
      custom_url = "http://localhost:#{custom_bypass.port}"

      Bypass.expect_once(custom_bypass, "POST", "/orders", fn conn ->
        Plug.Conn.resp(conn, 201, ~s({"id": "custom-success"}))
      end)

      result = Csv.run("test/fixtures/single_order.csv", custom_url)

      assert {:ok, [success_result]} = result
      assert {:ok, {0, success_response}} = success_result
      assert success_response.body["id"] == "custom-success"

      Bypass.down(custom_bypass)
    end

    test "handles malformed configuration gracefully" do
      # Temporarily set invalid base URL
      original_base_url = Application.get_env(:spread_connect_client, :base_url)
      Application.put_env(:spread_connect_client, :base_url, "invalid-url")

      # Should return results with error responses
      result = Csv.run("test/fixtures/single_order.csv")
      assert {:ok, [error_result]} = result
      assert {:error, {0, error_response}} = error_result
      assert error_response.status == 500
      assert String.contains?(error_response.body["error"], "scheme is required")

      # Restore original configuration
      Application.put_env(:spread_connect_client, :base_url, original_base_url)
    end
  end
end
