defmodule SpreadConnectClient.Parser.CsvParserTest do
  use ExUnit.Case, async: true
  alias SpreadConnectClient.Parser.CsvParser

  @fixtures_path "test/fixtures"

  describe "parse_file/1" do
    test "successfully parses a single line CSV file" do
      result =
        Path.join(@fixtures_path, "single_order.csv")
        |> CsvParser.parse_file()
        |> List.first()

      assert result.external_order_reference == "10001"
      assert result.email == "primeyouthsports@gmail.com"
      assert result.currency == "EUR"
      assert result.phone == "+4915224260416"

      # Verify order item
      [order_item] = result.order_items
      assert order_item.sku == "6739BC863E137_7907"
      assert order_item.quantity == 1
      assert %{amount: 18.98, currency: "EUR"} = order_item.customer_price

      # Verify shipping address
      assert result.shipping.preferred_type == "STANDARD"
      assert result.shipping.address.first_name == "Shane"
      assert result.shipping.address.last_name == "Ogilvie"
      assert result.shipping.address.country == "DE"
      assert result.shipping.address.city == "Berlin"
      assert result.shipping.address.street == "Niemetzstr. 16"
      assert result.shipping.address.zip_code == "12055"
      assert result.shipping.address.state == "BE"

      # Verify billing address
      assert result.billing_address.first_name == "Shane"
      assert result.billing_address.last_name == "Ogilvie"
      assert result.billing_address.country == "DE"
    end

    test "successfully groups multiple items from same order" do
      result =
        Path.join(@fixtures_path, "multiple_items.csv")
        |> CsvParser.parse_file()
        |> List.first()

      assert length(result.order_items) == 3
      assert result.external_order_reference == "10001"

      # Verify three order items are present
      [item1, item2, item3] = result.order_items

      assert item1.sku == "664B96E7ECCC4_7290"
      assert item2.sku == "6739B2AE6A3AD_9701"
      assert item3.sku == "6739B5D038C7C_16815"
    end

    test "handles invalid row format" do
      result =
        Path.join(@fixtures_path, "invalid_format.csv")
        |> CsvParser.parse_file()

      assert {:error, error_message} = result
      assert String.contains?(error_message, "CSV validation failed")
    end

    test "filters out rows with invalid fulfillment service" do
      result =
        Path.join(@fixtures_path, "test_orders_4.csv")
        |> CsvParser.parse_file()

      assert length(result) == 1
    end
  end

  describe "parse_file/1 edge cases" do
    test "handles missing email addresses" do
      result =
        Path.join(@fixtures_path, "edge_cases.csv")
        |> CsvParser.parse_file()
        |> List.first()

      assert result.email == "noemail@example.com"
    end

    test "handles invalid quantity values" do
      result =
        Path.join(@fixtures_path, "edge_cases.csv")
        |> CsvParser.parse_file()
        |> List.first()

      [order_item] = result.order_items
      assert order_item.quantity == 1
    end

    test "handles invalid price values" do
      result =
        Path.join(@fixtures_path, "edge_cases.csv")
        |> CsvParser.parse_file()
        |> List.first()

      [order_item] = result.order_items
      assert order_item.customer_price.amount == 0.0
    end

    test "handles missing recipient name" do
      result =
        Path.join(@fixtures_path, "edge_cases.csv")
        |> CsvParser.parse_file()
        |> List.first()

      assert result.shipping.address.first_name == nil
      assert result.shipping.address.last_name == nil
    end

    test "handles malformed phone numbers" do
      result =
        Path.join(@fixtures_path, "edge_cases.csv")
        |> CsvParser.parse_file()
        |> List.first()

      assert result.phone == "+4915224260416"
    end

    test "handles malformed data gracefully" do
      result =
        Path.join(@fixtures_path, "malformed_data.csv")
        |> CsvParser.parse_file()
        |> List.first()

      assert result.email == "invalid@example.com"
      
      assert String.length(result.shipping.address.first_name) <= 255
      assert String.length(result.shipping.address.last_name) <= 255
      
      assert result.shipping.address.country == "IN"
      assert result.shipping.address.state == "TE"
      
      assert String.contains?(result.shipping.address.city, "Berlin")
    end

    test "handles CSV rows with insufficient columns" do
      result =
        Path.join(@fixtures_path, "insufficient_columns.csv")
        |> CsvParser.parse_file()

      assert {:error, error_message} = result
      assert String.contains?(error_message, "Insufficient columns")
    end

    test "handles phone number conversion correctly" do
      test_data = [
        {"015224260416", "+4915224260416"},
        {"+4915224260416", "+4915224260416"},
        {"", ""},
      ]

      for {input, expected} <- test_data do
        csv_content = build_test_csv_with_phone(input)
        
        File.write!("test/fixtures/temp_phone_test.csv", csv_content)
        
        result = 
          "test/fixtures/temp_phone_test.csv"
          |> CsvParser.parse_file()
          |> List.first()

        if result do
          assert result.phone == expected
        end
      end

      File.rm("test/fixtures/temp_phone_test.csv")
    end

    test "handles email validation edge cases" do
      test_emails = [
        {"", "noemail@example.com"},
        {"invalid-email", "invalid@example.com"},
        {"test@", "invalid@example.com"},
        {"test@example.com", "test@example.com"},
      ]

      for {input_email, expected_email} <- test_emails do
        csv_content = build_test_csv_with_email(input_email)
        
        File.write!("test/fixtures/temp_email_test.csv", csv_content)
        
        result = 
          "test/fixtures/temp_email_test.csv"
          |> CsvParser.parse_file()
          |> List.first()

        if result do
          assert result.email == expected_email
        end
      end

      File.rm("test/fixtures/temp_email_test.csv")
    end

    test "handles name parsing edge cases" do
      test_names = [
        {"John Doe", "John", "Doe"},
        {"SingleName", "SingleName", "SingleName"},
        {"", nil, nil},
        {"John Middle Doe", "John", "Doe"},
        {nil, nil, nil}
      ]

      for {input_name, expected_first, expected_last} <- test_names do
        csv_content = build_test_csv_with_name(input_name)
        
        File.write!("test/fixtures/temp_name_test.csv", csv_content)
        
        result = 
          "test/fixtures/temp_name_test.csv"
          |> CsvParser.parse_file()
          |> List.first()

        if result do
          assert result.shipping.address.first_name == expected_first
          assert result.shipping.address.last_name == expected_last
        end
      end

      File.rm("test/fixtures/temp_name_test.csv")
    end

    test "handles numeric parsing edge cases" do
      test_quantities = [
        {"5", 5},
        {"0", 0},
        {"-1", -1},
        {"invalid", 1},
        {"", 1},
        {nil, 1}
      ]

      for {input_qty, expected_qty} <- test_quantities do
        csv_content = build_test_csv_with_quantity(input_qty)
        
        File.write!("test/fixtures/temp_qty_test.csv", csv_content)
        
        result = 
          "test/fixtures/temp_qty_test.csv"
          |> CsvParser.parse_file()
          |> List.first()

        if result do
          [order_item] = result.order_items
          assert order_item.quantity == expected_qty
        end
      end

      File.rm("test/fixtures/temp_qty_test.csv")
    end

    test "handles address normalization" do
      csv_content = build_test_csv_with_address("DEUTSCHLAND", "DE-BERLIN", "Berlin - Mitte Special")
      
      File.write!("test/fixtures/temp_address_test.csv", csv_content)
      
      result = 
        "test/fixtures/temp_address_test.csv"
        |> CsvParser.parse_file()
        |> List.first()

      assert result.shipping.address.country == "DE"
      assert result.shipping.address.state == "IN"
      assert result.shipping.address.city == "Berlin"

      File.rm("test/fixtures/temp_address_test.csv")
    end
  end

  # Helper functions for dynamic test CSV generation
  defp build_test_csv_with_phone(phone) do
    headers = "Order number,Date created,Time,Fulfill by,Total order quantity,Contact email,Note from customer,Additional checkout info,Item,Variant,SKU,Qty,Quantity refunded,Price,Weight,Custom text,Deposit amount,Delivery method,Delivery time,Recipient name,Recipient phone,Recipient company name,Delivery country,Delivery state,Delivery state name,Delivery city,Delivery address,Delivery zip/postal code,Billing name,Billing phone,Billing company name,Billing country,Delivery state,Delivery state name,Delivery city,Delivery address,Delivery zip/postal code,Payment status,Payment method,Coupon code,Gift card amount,Shipping rate,Total tax,Total,Currency,Refunded amount,Net amount,Additional fees,Fulfillment status,Tracking number,Fulfillment service,Shipping label"
    
    phone_str = if phone, do: "\"#{phone}\"", else: "\"\""
    
    row = "\"TEST001\",\"Dec 8, 2024\",\"9:15:51 AM\",\"\",\"1\",\"test@example.com\",\"\",\"\",\"Test Item\",\"\",\"TEST-SKU\",\"1\",\"0\",\"19.99\",\"0\",\"\",\"\",\"Standard\",\"\",\"John Doe\",#{phone_str},\"Test Company\",\"DEU\",\"DE-BE\",\"Berlin\",\"Berlin\",\"Test St 1\",\"12345\",\"John Doe\",#{phone_str},\"Test Company\",\"DEU\",\"DE-BE\",\"Berlin\",\"Berlin\",\"Test St 1\",\"12345\",\"Unpaid\",\"Manual\",\"\",\"\",\"0.00\",\"0.00\",\"19.99\",\"EUR\",\"0.00\",\"19.99\",\"0.00\",\"Unfulfilled\",\"\",\"Spreadconnect\",\"Test Label\""
    
    headers <> "\n" <> row
  end

  defp build_test_csv_with_email(email) do
    headers = "Order number,Date created,Time,Fulfill by,Total order quantity,Contact email,Note from customer,Additional checkout info,Item,Variant,SKU,Qty,Quantity refunded,Price,Weight,Custom text,Deposit amount,Delivery method,Delivery time,Recipient name,Recipient phone,Recipient company name,Delivery country,Delivery state,Delivery state name,Delivery city,Delivery address,Delivery zip/postal code,Billing name,Billing phone,Billing company name,Delivery country,Delivery state,Delivery state name,Delivery city,Delivery address,Delivery zip/postal code,Payment status,Payment method,Coupon code,Gift card amount,Shipping rate,Total tax,Total,Currency,Refunded amount,Net amount,Additional fees,Fulfillment status,Tracking number,Fulfillment service,Shipping label"
    
    email_str = if email, do: "\"#{email}\"", else: "\"\""
    
    row = "\"TEST001\",\"Dec 8, 2024\",\"9:15:51 AM\",\"\",\"1\",#{email_str},\"\",\"\",\"Test Item\",\"\",\"TEST-SKU\",\"1\",\"0\",\"19.99\",\"0\",\"\",\"\",\"Standard\",\"\",\"John Doe\",\"015224260416\",\"Test Company\",\"DEU\",\"DE-BE\",\"Berlin\",\"Berlin\",\"Test St 1\",\"12345\",\"John Doe\",\"015224260416\",\"Test Company\",\"DEU\",\"DE-BE\",\"Berlin\",\"Berlin\",\"Test St 1\",\"12345\",\"Unpaid\",\"Manual\",\"\",\"\",\"0.00\",\"0.00\",\"19.99\",\"EUR\",\"0.00\",\"19.99\",\"0.00\",\"Unfulfilled\",\"\",\"Spreadconnect\",\"Test Label\""
    
    headers <> "\n" <> row
  end

  defp build_test_csv_with_name(name) do
    headers = "Order number,Date created,Time,Fulfill by,Total order quantity,Contact email,Note from customer,Additional checkout info,Item,Variant,SKU,Qty,Quantity refunded,Price,Weight,Custom text,Deposit amount,Delivery method,Delivery time,Recipient name,Recipient phone,Recipient company name,Delivery country,Delivery state,Delivery state name,Delivery city,Delivery address,Delivery zip/postal code,Billing name,Billing phone,Billing company name,Delivery country,Delivery state,Delivery state name,Delivery city,Delivery address,Delivery zip/postal code,Payment status,Payment method,Coupon code,Gift card amount,Shipping rate,Total tax,Total,Currency,Refunded amount,Net amount,Additional fees,Fulfillment status,Tracking number,Fulfillment service,Shipping label"
    
    name_str = if name, do: "\"#{name}\"", else: "\"\""
    
    row = "\"TEST001\",\"Dec 8, 2024\",\"9:15:51 AM\",\"\",\"1\",\"test@example.com\",\"\",\"\",\"Test Item\",\"\",\"TEST-SKU\",\"1\",\"0\",\"19.99\",\"0\",\"\",\"\",\"Standard\",\"\",#{name_str},\"015224260416\",\"Test Company\",\"DEU\",\"DE-BE\",\"Berlin\",\"Berlin\",\"Test St 1\",\"12345\",#{name_str},\"015224260416\",\"Test Company\",\"DEU\",\"DE-BE\",\"Berlin\",\"Berlin\",\"Test St 1\",\"12345\",\"Unpaid\",\"Manual\",\"\",\"\",\"0.00\",\"0.00\",\"19.99\",\"EUR\",\"0.00\",\"19.99\",\"0.00\",\"Unfulfilled\",\"\",\"Spreadconnect\",\"Test Label\""
    
    headers <> "\n" <> row
  end

  defp build_test_csv_with_quantity(qty) do
    headers = "Order number,Date created,Time,Fulfill by,Total order quantity,Contact email,Note from customer,Additional checkout info,Item,Variant,SKU,Qty,Quantity refunded,Price,Weight,Custom text,Deposit amount,Delivery method,Delivery time,Recipient name,Recipient phone,Recipient company name,Delivery country,Delivery state,Delivery state name,Delivery city,Delivery address,Delivery zip/postal code,Billing name,Billing phone,Billing company name,Delivery country,Delivery state,Delivery state name,Delivery city,Delivery address,Delivery zip/postal code,Payment status,Payment method,Coupon code,Gift card amount,Shipping rate,Total tax,Total,Currency,Refunded amount,Net amount,Additional fees,Fulfillment status,Tracking number,Fulfillment service,Shipping label"
    
    qty_str = if qty, do: "\"#{qty}\"", else: "\"\""
    
    row = "\"TEST001\",\"Dec 8, 2024\",\"9:15:51 AM\",\"\",\"1\",\"test@example.com\",\"\",\"\",\"Test Item\",\"\",\"TEST-SKU\",#{qty_str},\"0\",\"19.99\",\"0\",\"\",\"\",\"Standard\",\"\",\"John Doe\",\"015224260416\",\"Test Company\",\"DEU\",\"DE-BE\",\"Berlin\",\"Berlin\",\"Test St 1\",\"12345\",\"John Doe\",\"015224260416\",\"Test Company\",\"DEU\",\"DE-BE\",\"Berlin\",\"Berlin\",\"Test St 1\",\"12345\",\"Unpaid\",\"Manual\",\"\",\"\",\"0.00\",\"0.00\",\"19.99\",\"EUR\",\"0.00\",\"19.99\",\"0.00\",\"Unfulfilled\",\"\",\"Spreadconnect\",\"Test Label\""
    
    headers <> "\n" <> row
  end

  defp build_test_csv_with_address(country, state, city) do
    headers = "Order number,Date created,Time,Fulfill by,Total order quantity,Contact email,Note from customer,Additional checkout info,Item,Variant,SKU,Qty,Quantity refunded,Price,Weight,Custom text,Deposit amount,Delivery method,Delivery time,Recipient name,Recipient phone,Recipient company name,Delivery country,Delivery state,Delivery state name,Delivery city,Delivery address,Delivery zip/postal code,Billing name,Billing phone,Billing company name,Delivery country,Delivery state,Delivery state name,Delivery city,Delivery address,Delivery zip/postal code,Payment status,Payment method,Coupon code,Gift card amount,Shipping rate,Total tax,Total,Currency,Refunded amount,Net amount,Additional fees,Fulfillment status,Tracking number,Fulfillment service,Shipping label"
    
    row = "\"TEST001\",\"Dec 8, 2024\",\"9:15:51 AM\",\"\",\"1\",\"test@example.com\",\"\",\"\",\"Test Item\",\"\",\"TEST-SKU\",\"1\",\"0\",\"19.99\",\"0\",\"\",\"\",\"Standard\",\"\",\"John Doe\",\"015224260416\",\"Test Company\",\"#{country}\",\"#{state}\",\"Berlin\",\"#{city}\",\"Test St 1\",\"12345\",\"John Doe\",\"015224260416\",\"Test Company\",\"#{country}\",\"#{state}\",\"Berlin\",\"#{city}\",\"Test St 1\",\"12345\",\"Unpaid\",\"Manual\",\"\",\"\",\"0.00\",\"0.00\",\"19.99\",\"EUR\",\"0.00\",\"19.99\",\"0.00\",\"Unfulfilled\",\"\",\"Spreadconnect\",\"Test Label\""
    
    headers <> "\n" <> row
  end
end
