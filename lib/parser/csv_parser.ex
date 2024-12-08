defmodule SpreadConnectClient.Parser.CsvParser do
  @moduledoc """
  Handles CSV file parsing for SpreadConnect data imports.
  """

  alias NimbleCSV.RFC4180, as: CSV
  alias SpreadConnectClient.Structs.{OrderItem, Shipping, Billing, Price, Address}

  def parse_file(file_path) do
    file_path
    |> File.stream!()
    |> CSV.parse_stream(skip_headers: true)
    |> Stream.map(&parse_row/1)
    |> Stream.map(&clean_values/1)
    |> Enum.to_list()
  end

  defp parse_row([order_number, _, _, _, _total_order_quantity, email, _, _, _, _, sku, qty, _, price,
    _, _, _, _, _, recipient_name, recipient_phone, recipient_company_name, delivery_country, _, delivery_state_name, delivery_city,
    delivery_address, delivery_postal_code, billing_name, _billing_phone, billing_company,
    billing_country, _, billing_state_name, billing_city, billing_address, billing_postal_code,
    _, _, _, _, _, _, _total, currency | _]) do

    %{
      order_item: %{
        sku: sku,
        external_order_item_reference: order_number,
        quantity: parse_integer(qty),
        customer_price: %Price{
          amount: parse_float(price),
          currency: currency
        }
      },
      phone: recipient_phone,
      shipping: %{
        preferred_type: "STANDARD",
        address: %{
          name: recipient_name,
          company: recipient_company_name,
          country: delivery_country,
          state: delivery_state_name,
          city: delivery_city,
          street: delivery_address,
          zip_code: delivery_postal_code
        },
        customer_price: %{
          amount: parse_float(price),
          currency: currency
        }
      },
      billing_address: %{
        name: billing_name,
        company: billing_company,
        country: billing_country,
        state: billing_state_name,
        city: billing_city,
        street: billing_address,
        zip_code: billing_postal_code
      },
      external_order_reference: order_number,
      currency: currency,
      email: email
    }
  end

  defp parse_row(invalid_row) do
    {:error, "Invalid row format: #{inspect(invalid_row)}"}
  end

  defp clean_values(%{} = map) do
    map
    |> Map.update!(:billing, &clean_map_values/1)
    |> Map.update!(:delivery, &clean_map_values/1)
    |> Map.update!(:recipient_phone, &clean_string/1)
  end

  defp clean_map_values(%{} = map) do
    Map.new(map, fn {k, v} -> {k, clean_string(v)} end)
  end

  defp clean_string(value) when is_binary(value) do
    value
    |> String.replace("\"", "")
    |> String.trim()
  end
  defp clean_string(value), do: value

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {number, _} -> number
      :error -> 0
    end
  end

  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {number, _} -> number
      :error -> 0.0
    end
  end
end
