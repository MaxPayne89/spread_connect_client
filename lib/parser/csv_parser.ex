defmodule SpreadConnectClient.Parser.CsvParser do
  @moduledoc """
  Handles CSV file parsing for SpreadConnect data imports.
  """

  alias NimbleCSV.RFC4180, as: CSV

  @spec parse_file(String.t()) :: [map()]
  def parse_file(file_path) do
    file_path
    |> File.stream!()
    |> CSV.parse_stream(skip_headers: true)
    |> Stream.map(&parse_row/1)
    |> Stream.filter(&match?({:ok, _}, &1))
    |> Stream.map(fn {:ok, data} -> data end)
    |> Stream.map(&clean_values/1)
    |> Enum.reduce(%{}, &group_by_order_number/2)
    |> Map.values()
  end

  defp parse_row([
         order_number,
         _,
         _,
         _,
         _total_order_quantity,
         email,
         _,
         _,
         _,
         _,
         sku,
         qty,
         _,
         price,
         _,
         _,
         _,
         _,
         _,
         recipient_name,
         recipient_phone,
         recipient_company_name,
         delivery_country,
         delivery_state,
         _delivery_state_name,
         delivery_city,
         delivery_address,
         delivery_postal_code,
         billing_name,
         _billing_phone,
         billing_company,
         billing_country,
         billing_state,
         _billing_state_name,
         billing_city,
         billing_address,
         billing_postal_code,
         _,
         _,
         _,
         _,
         _,
         _,
         _total,
         currency | _
       ]) do
    {:ok,
     %{
       order_item: %{
         sku: sku,
         external_order_item_reference: order_number,
         quantity: parse_integer(qty),
         customer_price: %{
           amount: parse_float(price),
           currency: currency
         }
       },
       phone: parse_phone(recipient_phone),
       shipping: %{
         preferred_type: "STANDARD",
         address: %{
           first_name: parse_first_name(recipient_name),
           last_name: parse_last_name(recipient_name),
           company: recipient_company_name,
           country: parse_country(delivery_country),
           state: parse_state(delivery_state),
           city: parse_city(delivery_city),
           street: delivery_address,
           zip_code: delivery_postal_code
         },
         customer_price: %{
           amount: parse_float(price),
           currency: currency
         }
       },
       billing_address: %{
         first_name: parse_first_name(billing_name),
         last_name: parse_last_name(billing_name),
         company: billing_company,
         country: parse_country(billing_country),
         state: parse_state(billing_state),
         city: parse_city(billing_city),
         street: billing_address,
         zip_code: billing_postal_code
       },
       external_order_reference: order_number,
       currency: currency,
       email: email
     }}
  end

  defp parse_row(invalid_row) do
    {:error, "Invalid row format: #{inspect(invalid_row)}"}
  end

  defp clean_values(%{} = map) do
    map
    |> Map.update!(:billing_address, &clean_map_values/1)
    |> update_in([:shipping, :address], &clean_map_values/1)
    |> Map.update!(:phone, &clean_string/1)
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

  defp parse_first_name(value) when is_binary(value) do
    value
    |> String.replace("\"", "")
    |> String.trim()
    |> String.split()
    |> List.first()
  end

  defp parse_first_name(value), do: value

  defp parse_last_name(value) when is_binary(value) do
    value
    |> String.replace("\"", "")
    |> String.trim()
    |> String.split()
    |> List.last()
  end

  defp parse_last_name(value), do: value

  defp parse_country(value) when is_binary(value) do
    value
    |> String.slice(0..1)
  end

  defp parse_country(value), do: value

  defp parse_city(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.replace(~r/[^a-zA-Z].*$/, "")
  end

  defp parse_city(value), do: value

  defp parse_state(value) when is_binary(value) do
    value
    |> String.slice(-2..-1)
  end

  defp parse_state(value), do: value

  defp group_by_order_number(row, acc) do
    order_number = row.external_order_reference

    case Map.get(acc, order_number) do
      nil ->
        # First occurrence of this order number
        Map.put(acc, order_number, %{
          order_items: [row.order_item],
          phone: row.phone,
          shipping: row.shipping,
          billing_address: row.billing_address,
          external_order_reference: order_number,
          currency: row.currency,
          email: row.email
        })

      existing_order ->
        # Add the order item to existing order
        Map.put(acc, order_number, %{
          existing_order
          | order_items: [row.order_item | existing_order.order_items]
        })
    end
  end

  defp parse_phone(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.replace("\"", "")
    |> String.replace(~r/^0/, "+49")
  end

  defp parse_phone(value), do: value
end
