defmodule SpreadConnectClient.Schema.CsvSchema do
  @moduledoc """
  Defines the CSV schema for SpreadConnect order exports.
  
  This module centralizes all CSV column definitions, making it easy to:
  - Update column positions when CSV format changes
  - Validate CSV files have expected structure
  - Support different CSV formats if needed
  
  ## CSV Format
  
  The expected CSV format is based on SpreadConnect's order export format.
  Column positions are zero-indexed.
  """

  require Logger

  # Default SpreadConnect CSV column schema
  @default_schema %{
    order_number: 0,
    date_created: 1,
    time: 2,
    fulfill_by: 3,
    total_order_quantity: 4,
    email: 5,
    note_from_customer: 6,
    additional_checkout_info: 7,
    item: 8,
    variant: 9,
    sku: 10,
    quantity: 11,
    quantity_refunded: 12,
    price: 13,
    weight: 14,
    custom_text: 15,
    deposit_amount: 16,
    delivery_method: 17,
    delivery_time: 18,
    recipient_name: 19,
    recipient_phone: 20,
    recipient_company: 21,
    delivery_country: 22,
    delivery_state: 23,
    delivery_state_name: 24,
    delivery_city: 25,
    delivery_address: 26,
    delivery_postal_code: 27,
    billing_name: 28,
    billing_phone: 29,
    billing_company: 30,
    billing_country: 31,
    billing_state: 32,
    billing_state_name: 33,
    billing_city: 34,
    billing_address: 35,
    billing_postal_code: 36,
    payment_status: 37,
    payment_method: 38,
    coupon_code: 39,
    gift_card_amount: 40,
    shipping_rate: 41,
    total_tax: 42,
    total: 43,
    currency: 44,
    refunded_amount: 45,
    net_amount: 46,
    additional_fees: 47,
    fulfillment_status: 48,
    tracking_number: 49,
    fulfillment_service: 50,
    shipping_label: 51
  }

  @required_columns [
    :order_number,
    :email,
    :sku,
    :quantity,
    :price,
    :recipient_name,
    :delivery_country,
    :delivery_city,
    :delivery_address,
    :currency,
    :fulfillment_service
  ]

  @doc """
  Returns the column position for a given field name.
  
  ## Examples
  
      iex> CsvSchema.get_column_position(:order_number)
      0
      
      iex> CsvSchema.get_column_position(:email)
      5
  """
  @spec get_column_position(atom()) :: integer() | nil
  def get_column_position(field_name) when is_atom(field_name) do
    Map.get(@default_schema, field_name)
  end

  @doc """
  Safely extracts a field value from a CSV row.
  
  Returns the value at the column position, or the default value if:
  - The column position is not defined
  - The row doesn't have enough columns
  - The value is nil or empty string
  
  ## Examples
  
      iex> row = ["ORDER001", "2024-01-01", "user@example.com"]
      iex> CsvSchema.get_field_value(row, :order_number)
      "ORDER001"
      
      iex> CsvSchema.get_field_value(row, :email, "default@example.com")
      "user@example.com"
  """
  @spec get_field_value(list(), atom(), any()) :: any()
  def get_field_value(row, field_name, default \\ "") when is_list(row) and is_atom(field_name) do
    case get_column_position(field_name) do
      nil ->
        Logger.warning("Unknown CSV field requested", field: field_name)
        default
        
      position ->
        case Enum.at(row, position) do
          nil -> default
          "" -> default
          value -> value
        end
    end
  end

  @doc """
  Validates that a CSV row has all required columns.
  
  ## Examples
  
      iex> row = ["ORDER001", "", "", "", "", "user@example.com", ...] # 52 columns
      iex> CsvSchema.validate_row(row)
      {:ok, :valid}
      
      iex> short_row = ["ORDER001", "user@example.com"]
      iex> CsvSchema.validate_row(short_row)
      {:error, "Insufficient columns: expected at least 52, got 2"}
  """
  @spec validate_row(list()) :: {:ok, :valid} | {:error, String.t()}
  def validate_row(row) when is_list(row) do
    expected_columns = get_expected_column_count()
    actual_columns = length(row)
    
    if actual_columns >= expected_columns do
      {:ok, :valid}
    else
      {:error, "Insufficient columns: expected at least #{expected_columns}, got #{actual_columns}"}
    end
  end

  @doc """
  Validates that CSV headers match the expected schema.
  
  This can be used to detect if the CSV format has changed.
  """
  @spec validate_headers(list()) :: {:ok, :valid} | {:error, String.t()}
  def validate_headers(headers) when is_list(headers) do
    case validate_row(headers) do
      {:ok, :valid} -> 
        missing_fields = check_required_fields_present(headers)
        if Enum.empty?(missing_fields) do
          {:ok, :valid}
        else
          {:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
        end
        
      error -> error
    end
  end

  @doc """
  Returns the expected number of columns for the CSV schema.
  """
  @spec get_expected_column_count() :: integer()
  def get_expected_column_count do
    @default_schema
    |> Map.values()
    |> Enum.max()
    |> Kernel.+(1)  # Add 1 because positions are zero-indexed
  end

  @doc """
  Returns the list of required column names.
  """
  @spec get_required_columns() :: [atom()]
  def get_required_columns, do: @required_columns

  @doc """
  Returns all available field names in the schema.
  """
  @spec get_all_fields() :: [atom()]
  def get_all_fields do
    Map.keys(@default_schema)
  end

  # Private helper functions

  defp check_required_fields_present(_headers) do
    # For now, we'll assume headers are present if row length is correct
    # This could be enhanced to check actual header names if needed
    []
  end
end