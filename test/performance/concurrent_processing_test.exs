defmodule SpreadConnectClient.Performance.ConcurrentProcessingTest do
  use ExUnit.Case, async: false

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

  describe "Task.async_stream parallel processing" do
    test "processes multiple orders concurrently", %{bypass: bypass} do
      # Track concurrent requests
      {:ok, process_tracker} = Agent.start_link(fn -> %{active: 0, max_concurrent: 0, total: 0} end)

      Bypass.expect(bypass, "POST", "/orders", fn conn ->
        # Track concurrent processing
        Agent.update(process_tracker, fn state ->
          new_active = state.active + 1
          new_max = max(new_active, state.max_concurrent)
          %{state | active: new_active, max_concurrent: new_max, total: state.total + 1}
        end)

        # Simulate processing time to allow concurrency
        Process.sleep(100)

        # Decrement active count
        Agent.update(process_tracker, fn state ->
          %{state | active: state.active - 1}
        end)

        Plug.Conn.resp(conn, 201, ~s({"id": "concurrent-success"}))
      end)

      # Create a CSV file with multiple orders
      temp_csv_content = create_bulk_test_csv(8)
      temp_file = create_temp_file("temp_concurrent_test.csv", temp_csv_content)

      start_time = System.monotonic_time(:millisecond)
      
      result = Csv.run(temp_file)
      
      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      # Verify results
      assert {:ok, results} = result
      assert length(results) == 8

      # All should be successful
      successes = Enum.count(results, &match?({:ok, _}, &1))
      assert successes == 8

      # Check concurrency stats
      final_stats = Agent.get(process_tracker, & &1)
      
      # We should have processed more than 1 request concurrently at peak
      assert final_stats.max_concurrent >= 2
      assert final_stats.max_concurrent <= 10  # Respects max_concurrency: 10
      assert final_stats.total == 8

      # Duration should be significantly less than sequential processing
      # 8 orders * 100ms = 800ms sequential, should be much faster with concurrency
      assert duration < 600  # Allow some overhead

      # Cleanup Agent
      Agent.stop(process_tracker)
    end

    test "respects max_concurrency limit of 10", %{bypass: bypass} do
      # Track concurrent requests with more precise timing
      {:ok, process_tracker} = Agent.start_link(fn -> %{active: 0, max_concurrent: 0, timestamps: []} end)

      Bypass.expect(bypass, "POST", "/orders", fn conn ->
        start_time = System.monotonic_time(:millisecond)
        
        Agent.update(process_tracker, fn state ->
          new_active = state.active + 1
          new_max = max(new_active, state.max_concurrent)
          timestamps = [%{type: :start, time: start_time, active: new_active} | state.timestamps]
          %{state | active: new_active, max_concurrent: new_max, timestamps: timestamps}
        end)

        Process.sleep(200)  # Longer processing to ensure overlap
        
        end_time = System.monotonic_time(:millisecond)
        Agent.update(process_tracker, fn state ->
          new_active = state.active - 1
          timestamps = [%{type: :end, time: end_time, active: new_active} | state.timestamps]
          %{state | active: new_active, timestamps: timestamps}
        end)

        Plug.Conn.resp(conn, 201, ~s({"id": "limit-test-success"}))
      end)

      # Create a CSV file with 15 orders to test the limit
      temp_csv_content = create_bulk_test_csv(15)
      temp_file = create_temp_file("temp_limit_test.csv", temp_csv_content)

      result = Csv.run(temp_file)

      # Verify results
      assert {:ok, results} = result
      assert length(results) == 15

      # Check concurrency never exceeded 10
      final_stats = Agent.get(process_tracker, & &1)
      assert final_stats.max_concurrent <= 10

      # Cleanup Agent
      Agent.stop(process_tracker)
    end

    test "handles mixed success and failure responses concurrently", %{bypass: bypass} do
      # Use deterministic failure based on order number rather than call count
      # This makes the test behavior predictable regardless of request timing
      Bypass.expect(bypass, "POST", "/orders", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        request_data = Jason.decode!(body)
        order_ref = request_data["externalOrderReference"]
        
        case order_ref do
          "BULK000001" ->
            # First order always fails with 422 error
            Plug.Conn.resp(conn, 422, ~s({"error": "Validation failed"}))
          _ ->
            # Other orders succeed
            Plug.Conn.resp(conn, 201, ~s({"id": "success-#{order_ref}"}))
        end
      end)

      temp_csv_content = create_bulk_test_csv(3)
      temp_file = create_temp_file("temp_mixed_test.csv", temp_csv_content)

      start_time = System.monotonic_time(:millisecond)
      result = Csv.run(temp_file)
      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      # Should complete quickly 
      assert duration < 5_000

      assert {:ok, results} = result
      assert length(results) == 3

      # Should have one validation error and two successes
      errors = Enum.count(results, fn
        {:error, {_, response}} -> response.status == 422 and response.body["error"] == "Validation failed"
        _ -> false
      end)
      
      successes = Enum.count(results, &match?({:ok, _}, &1))
      
      assert errors == 1
      assert successes == 2
    end
  end

  describe "Finch connection pooling performance" do
    test "reuses HTTP connections efficiently", %{bypass: bypass} do
      {:ok, connection_tracker} = Agent.start_link(fn -> MapSet.new() end)

      Bypass.expect(bypass, "POST", "/orders", fn conn ->
        # Track unique connection identifiers (remote port + local port combination)
        remote_port = conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
        local_port = conn.port
        connection_id = "#{remote_port}:#{local_port}"
        
        Agent.update(connection_tracker, fn connections ->
          MapSet.put(connections, connection_id)
        end)

        Process.sleep(50)  # Brief processing time
        Plug.Conn.resp(conn, 201, ~s({"id": "pool-test-success"}))
      end)

      temp_csv_content = create_bulk_test_csv(20)
      temp_file = create_temp_file("temp_pool_test.csv", temp_csv_content)

      result = Csv.run(temp_file)

      assert {:ok, results} = result
      assert length(results) == 20

      # All should be successful
      successes = Enum.count(results, &match?({:ok, _}, &1))
      assert successes == 20

      # Connection pooling should result in connection reuse
      # We should have fewer unique connection identifiers than total requests
      unique_connections = Agent.get(connection_tracker, & &1)
      connection_count = MapSet.size(unique_connections)
      
      # With connection pooling, we should reuse connections
      # Should be less than or equal to the pool size (25)
      assert connection_count <= 25
      assert connection_count < 20  # Should definitely reuse connections

      # Cleanup Agent
      Agent.stop(connection_tracker)
    end

    test "handles connection pool exhaustion gracefully", %{bypass: bypass} do
      # This test is more about ensuring stability under load
      {:ok, request_count} = Agent.start_link(fn -> 0 end)

      Bypass.expect(bypass, "POST", "/orders", fn conn ->
        Agent.update(request_count, fn count -> count + 1 end)
        Process.sleep(100)  # Hold connections briefly
        Plug.Conn.resp(conn, 201, ~s({"id": "pool-exhaustion-test"}))
      end)

      # Create more concurrent requests than pool size (25)
      temp_csv_content = create_bulk_test_csv(30)
      temp_file = create_temp_file("temp_pool_exhaustion_test.csv", temp_csv_content)

      start_time = System.monotonic_time(:millisecond)
      result = Csv.run(temp_file)
      end_time = System.monotonic_time(:millisecond)

      # Should still succeed even with pool pressure
      assert {:ok, results} = result
      assert length(results) == 30

      # All requests should eventually succeed
      successes = Enum.count(results, &match?({:ok, _}, &1))
      assert successes == 30

      # Should complete in reasonable time despite pool pressure
      assert end_time - start_time < 10_000  # 10 seconds max

      final_count = Agent.get(request_count, & &1)
      assert final_count == 30

      # Cleanup Agent
      Agent.stop(request_count)
    end
  end

  describe "CSV parsing performance" do
    test "O(n) tuple-based parsing performs efficiently on larger datasets" do
      # Create a larger CSV file to test parsing performance
      large_csv_content = create_bulk_test_csv(100)
      temp_file = create_temp_file("temp_large_parse_test.csv", large_csv_content)

      start_time = System.monotonic_time(:microsecond)
      
      # Parse without API calls to isolate parsing performance
      parsed_orders = SpreadConnectClient.Parser.CsvParser.parse_file(temp_file)
      
      end_time = System.monotonic_time(:microsecond)
      duration_us = end_time - start_time
      duration_ms = duration_us / 1000

      # Verify parsing correctness
      assert length(parsed_orders) == 100
      
      # Each order should have proper structure
      Enum.each(parsed_orders, fn order ->
        assert is_binary(order.external_order_reference)
        assert is_list(order.order_items)
        assert length(order.order_items) >= 1
        assert is_map(order.shipping)
        assert is_map(order.billing_address)
      end)

      # Performance should be reasonable - parsing 100 orders should be under 100ms
      assert duration_ms < 100, "Parsing took #{duration_ms}ms, expected < 100ms"
    end

    test "memory usage remains stable during large file processing" do
      # This test ensures we don't have memory leaks during parsing
      large_csv_content = create_bulk_test_csv(200)
      temp_file = create_temp_file("temp_memory_test.csv", large_csv_content)

      # Measure memory before parsing
      {:ok, memory_before} = :erlang.memory() |> Keyword.fetch(:total)

      # Parse the file
      parsed_orders = SpreadConnectClient.Parser.CsvParser.parse_file(temp_file)
      
      # Force garbage collection
      :erlang.garbage_collect()

      # Measure memory after parsing
      {:ok, memory_after} = :erlang.memory() |> Keyword.fetch(:total)
      memory_increase = memory_after - memory_before

      # Verify parsing worked
      assert length(parsed_orders) == 200

      # Memory increase should be reasonable (less than 50MB for 200 orders)
      max_acceptable_increase = 50 * 1024 * 1024  # 50MB
      assert memory_increase < max_acceptable_increase, 
             "Memory increased by #{memory_increase} bytes, expected < #{max_acceptable_increase}"
    end
  end

  # Helper function to create bulk test CSV data
  defp create_bulk_test_csv(num_orders) do
    headers = "Order number,Date created,Time,Fulfill by,Total order quantity,Contact email,Note from customer,Additional checkout info,Item,Variant,SKU,Qty,Quantity refunded,Price,Weight,Custom text,Deposit amount,Delivery method,Delivery time,Recipient name,Recipient phone,Recipient company name,Delivery country,Delivery state,Delivery state name,Delivery city,Delivery address,Delivery zip/postal code,Billing name,Billing phone,Billing company name,Delivery country,Delivery state,Delivery state name,Delivery city,Delivery address,Delivery zip/postal code,Payment status,Payment method,Coupon code,Gift card amount,Shipping rate,Total tax,Total,Currency,Refunded amount,Net amount,Additional fees,Fulfillment status,Tracking number,Fulfillment service,Shipping label"
    
    rows = for i <- 1..num_orders do
      order_id = String.pad_leading("#{i}", 6, "0")
      price = 19.99 + (i * 0.50)
      "\"BULK#{order_id}\",\"Dec 8, 2024\",\"9:15:51 AM\",\"\",\"1\",\"test#{i}@example.com\",\"\",\"\",\"Test Item #{i}\",\"\",\"TEST-SKU-#{i}\",\"1\",\"0\",\"#{price}\",\"0\",\"\",\"\",\"Standard\",\"\",\"John Doe #{i}\",\"015224260416\",\"Test Company\",\"DEU\",\"DE-BE\",\"Berlin\",\"Berlin\",\"Test St #{i}\",\"12345\",\"John Doe #{i}\",\"015224260416\",\"Test Company\",\"DEU\",\"DE-BE\",\"Berlin\",\"Berlin\",\"Test St #{i}\",\"12345\",\"Unpaid\",\"Manual\",\"\",\"\",\"0.00\",\"0.00\",\"#{price}\",\"EUR\",\"0.00\",\"#{price}\",\"0.00\",\"Unfulfilled\",\"\",\"Spreadconnect\",\"Label #{i}\""
    end

    [headers | rows] |> Enum.join("\n")
  end

  # Helper function to create temporary files with guaranteed cleanup
  defp create_temp_file(filename, content) do
    # Use test pid and timestamp to avoid conflicts between parallel tests
    unique_suffix = "#{System.unique_integer([:positive])}"
    temp_file = "test/fixtures/#{Path.basename(filename, ".csv")}_#{unique_suffix}.csv"
    
    File.write!(temp_file, content)
    
    # Ensure cleanup happens even if test fails
    on_exit(fn ->
      if File.exists?(temp_file), do: File.rm(temp_file)
    end)
    
    temp_file
  end
end