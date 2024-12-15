defmodule SpreadConnectClient.Parser.CsvParserTest do
  use ExUnit.Case, async: true
  alias SpreadConnectClient.Parser.CsvParser
  alias SpreadConnectClient.Structs.Price

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
      assert %Price{amount: 18.98, currency: "EUR"} = order_item.customer_price

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

      assert result == []
    end
  end
end
