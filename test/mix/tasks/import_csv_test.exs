defmodule SpreadConnectClient.Integration.CsvImportTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Import.Csv

  setup do
    bypass = Bypass.open()
    Application.put_env(:spread_connect_client, :base_url, "http://localhost:#{bypass.port}")
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
end
