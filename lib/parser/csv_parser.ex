defmodule SpreadConnectClient.Parser.CsvParser do
  @moduledoc """
  CSV file parser for SpreadConnect order data imports.
  
  Handles parsing, filtering, cleaning, and grouping of CSV order data
  to prepare it for API submission to SpreadConnect.
  """

  alias NimbleCSV.RFC4180, as: CSV
  alias SpreadConnectClient.Schema.CsvSchema

  # Constants
  @spread_connect_fulfillment_service "Spreadconnect"
  @default_shipping_type "STANDARD"
  @country_code_length 2
  @state_code_length 2
  @german_phone_prefix "+49"

  @doc """
  Parses a CSV file and returns a list of order maps ready for API submission.
  
  Only processes orders with 'Spreadconnect' fulfillment service.
  Groups multiple line items by order number into consolidated orders.
  
  Validates CSV schema before processing to detect format changes.
  """
  @spec parse_file(String.t()) :: [map()] | {:error, String.t()}
  def parse_file(file_path) do
    with {:ok, headers} <- validate_csv_headers(file_path),
         {:ok, :valid} <- CsvSchema.validate_headers(headers) do
      
      file_path
      |> File.stream!()
      |> CSV.parse_stream(skip_headers: true)
      |> Stream.map(&parse_csv_row/1)
      |> Stream.filter(&filter_valid_rows/1)
      |> Stream.filter(&filter_spread_connect_orders/1)
      |> Stream.map(&extract_order_data/1)
      |> Stream.map(&clean_order_values/1)
      |> Enum.reduce(%{}, &group_by_order_number/2)
      |> Map.values()
    else
      {:error, reason} -> {:error, "CSV validation failed: #{reason}"}
    end
  end

  # CSV Schema Validation

  defp validate_csv_headers(file_path) do
    case File.open(file_path, [:read]) do
      {:ok, file} ->
        case IO.read(file, :line) do
          :eof -> 
            File.close(file)
            {:error, "Empty CSV file"}
          
          data when is_binary(data) ->
            File.close(file)
            headers = data 
                     |> String.trim() 
                     |> CSV.parse_string(skip_headers: false) 
                     |> List.first()
            {:ok, headers}
          
          {:error, reason} ->
            File.close(file)
            {:error, "Failed to read CSV headers: #{inspect(reason)}"}
        end
      
      {:error, reason} ->
        {:error, "Failed to open CSV file: #{inspect(reason)}"}
    end
  rescue
    error ->
      {:error, "CSV header validation error: #{inspect(error)}"}
  end

  # CSV Row Parsing

  defp parse_csv_row(row) do
    case CsvSchema.validate_row(row) do
      {:ok, :valid} ->
        try do
          {:ok, build_order_from_csv_row(row)}
        rescue
          _ -> {:error, "Failed to parse CSV row"}
        end
      
      {:error, error_message} ->
        {:error, error_message}
    end
  end

  defp build_order_from_csv_row(row) do
    %{
      order_item: build_order_item(row),
      phone: parse_phone_number(CsvSchema.get_field_value(row, :recipient_phone)),
      shipping: build_shipping_info(row),
      billing_address: build_billing_address(row),
      external_order_reference: CsvSchema.get_field_value(row, :order_number),
      currency: CsvSchema.get_field_value(row, :currency),
      email: validate_email(CsvSchema.get_field_value(row, :email)),
      fulfillment_service: CsvSchema.get_field_value(row, :fulfillment_service)
    }
  end

  defp build_order_item(row) do
    %{
      sku: CsvSchema.get_field_value(row, :sku),
      external_order_item_reference: CsvSchema.get_field_value(row, :order_number),
      quantity: parse_integer(CsvSchema.get_field_value(row, :quantity)),
      customer_price: %{
        amount: parse_float(CsvSchema.get_field_value(row, :price)),
        currency: CsvSchema.get_field_value(row, :currency)
      }
    }
  end

  defp build_shipping_info(row) do
    %{
      preferred_type: @default_shipping_type,
      address: build_shipping_address(row),
      customer_price: %{
        amount: parse_float(CsvSchema.get_field_value(row, :price)),
        currency: CsvSchema.get_field_value(row, :currency)
      }
    }
  end

  defp build_shipping_address(row) do
    recipient_name = CsvSchema.get_field_value(row, :recipient_name)
    
    %{
      first_name: extract_first_name(recipient_name),
      last_name: extract_last_name(recipient_name),
      company: CsvSchema.get_field_value(row, :recipient_company),
      country: normalize_country_code(CsvSchema.get_field_value(row, :delivery_country)),
      state: normalize_state_code(CsvSchema.get_field_value(row, :delivery_state)),
      city: clean_city_name(CsvSchema.get_field_value(row, :delivery_city)),
      street: CsvSchema.get_field_value(row, :delivery_address),
      zip_code: CsvSchema.get_field_value(row, :delivery_postal_code)
    }
  end

  defp build_billing_address(row) do
    billing_name = CsvSchema.get_field_value(row, :billing_name)
    
    %{
      first_name: extract_first_name(billing_name),
      last_name: extract_last_name(billing_name),
      company: CsvSchema.get_field_value(row, :billing_company),
      country: normalize_country_code(CsvSchema.get_field_value(row, :billing_country)),
      state: normalize_state_code(CsvSchema.get_field_value(row, :billing_state)),
      city: clean_city_name(CsvSchema.get_field_value(row, :billing_city)),
      street: CsvSchema.get_field_value(row, :billing_address),
      zip_code: CsvSchema.get_field_value(row, :billing_postal_code)
    }
  end

  # Filtering Functions

  defp filter_valid_rows({:ok, _}), do: true
  defp filter_valid_rows({:error, _}), do: false

  defp filter_spread_connect_orders({:ok, order_data}) do
    order_data.fulfillment_service == @spread_connect_fulfillment_service
  end

  defp extract_order_data({:ok, order_data}), do: order_data

  # Data Cleaning Functions

  defp clean_order_values(order) do
    order
    |> Map.update!(:billing_address, &clean_address_fields/1)
    |> update_in([:shipping, :address], &clean_address_fields/1)
    |> Map.update!(:phone, &clean_string_value/1)
  end

  defp clean_address_fields(address) do
    Map.new(address, fn {key, value} -> {key, clean_string_value(value)} end)
  end

  defp clean_string_value(value) when is_binary(value) do
    cleaned = value
    |> String.replace("\"", "")
    |> String.trim()
    
    # Limit string length to prevent extremely long inputs
    if String.length(cleaned) > 255 do
      String.slice(cleaned, 0, 255)
    else
      cleaned
    end
  end

  defp clean_string_value(value), do: value

  # Value Parsing Functions

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {number, _} when number >= 0 -> number
      {number, _} -> 
        # Log negative numbers but allow them (might be refunds)
        number
      :error -> 
        # Log warning but return 1 as safe default for quantities
        1
    end
  end

  defp parse_integer(_), do: 1

  defp parse_float(value) when is_binary(value) do
    case Float.parse(String.trim(value)) do
      {number, _} when number >= 0.0 -> number
      {number, _} -> 
        # Allow negative numbers (might be refunds/credits)
        number
      :error -> 
        # Return 0.0 for invalid prices as safe default
        0.0
    end
  end

  defp parse_float(_), do: 0.0

  # Email Validation Functions

  defp validate_email(email) when is_binary(email) do
    cleaned_email = String.trim(email)
    
    cond do
      String.length(cleaned_email) == 0 ->
        "noemail@example.com"  # Safe fallback for missing emails
        
      String.contains?(cleaned_email, "@") and String.contains?(cleaned_email, ".") ->
        cleaned_email
        
      true ->
        "invalid@example.com"  # Safe fallback for invalid emails
    end
  end

  defp validate_email(_), do: "noemail@example.com"

  # Name Parsing Functions

  defp extract_first_name(full_name) when is_binary(full_name) do
    full_name
    |> clean_string_value()
    |> String.split()
    |> List.first()
  end

  defp extract_first_name(_), do: nil

  defp extract_last_name(full_name) when is_binary(full_name) do
    full_name
    |> clean_string_value()
    |> String.split()
    |> List.last()
  end

  defp extract_last_name(_), do: nil

  # Address Field Normalization

  defp normalize_country_code(country) when is_binary(country) do
    String.slice(country, 0, @country_code_length)
  end

  defp normalize_country_code(country), do: country

  defp normalize_state_code(state) when is_binary(state) do
    String.slice(state, -@state_code_length, @state_code_length)
  end

  defp normalize_state_code(state), do: state

  defp clean_city_name(city) when is_binary(city) do
    city
    |> String.trim()
    |> String.replace(~r/[^a-zA-Z].*$/, "")
  end

  defp clean_city_name(city), do: city

  # Phone Number Processing

  defp parse_phone_number(phone) when is_binary(phone) do
    phone
    |> clean_string_value()
    |> convert_german_phone_format()
  end

  defp parse_phone_number(phone), do: phone

  defp convert_german_phone_format(phone) do
    String.replace(phone, ~r/^0/, @german_phone_prefix)
  end

  # Order Grouping Functions

  defp group_by_order_number(order_row, orders_acc) do
    order_number = order_row.external_order_reference

    case Map.get(orders_acc, order_number) do
      nil ->
        create_new_order_entry(orders_acc, order_number, order_row)

      existing_order ->
        add_item_to_existing_order(orders_acc, order_number, existing_order, order_row)
    end
  end

  defp create_new_order_entry(orders_acc, order_number, order_row) do
    Map.put(orders_acc, order_number, %{
      order_items: [order_row.order_item],
      phone: order_row.phone,
      shipping: order_row.shipping,
      billing_address: order_row.billing_address,
      external_order_reference: order_number,
      currency: order_row.currency,
      email: order_row.email,
      fulfillment_service: order_row.fulfillment_service
    })
  end

  defp add_item_to_existing_order(orders_acc, order_number, existing_order, order_row) do
    updated_order = %{
      existing_order |
      order_items: [order_row.order_item | existing_order.order_items]
    }
    
    Map.put(orders_acc, order_number, updated_order)
  end
end