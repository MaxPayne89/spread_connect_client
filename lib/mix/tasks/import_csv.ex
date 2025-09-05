defmodule Mix.Tasks.Import.Csv do
  @moduledoc """
  Mix task for importing CSV order data to SpreadConnect API.
  
  Processes CSV files containing order data, parses and validates the data,
  then submits each order to the SpreadConnect API with progress tracking
  and comprehensive error reporting.

  ## Usage

      mix import.csv path/to/orders.csv

  ## Configuration

  The task uses application configuration for API endpoints and authentication.
  Ensure your config files are properly set up for your target environment.

  ## Examples

      # Import from a CSV file
      mix import.csv /path/to/orders.csv
      
      # The task will show progress and provide a summary:
      # Starting import of /path/to/orders.csv
      # Successfully read file with 4748 bytes
      # Import Summary:
      # Successfully processed: 5 records
      # Failed to process: 0 records
  """

  use Mix.Task

  alias SpreadConnectClient.Parser.CsvParser
  alias SpreadConnectClient.Client.SpreadConnectClient

  @shortdoc "Import CSV order data to SpreadConnect API"

  @doc """
  Executes the CSV import task.

  ## Parameters
    * `file_path` - Path to the CSV file to import
    * `base_url` - Optional API base URL override (for testing)

  ## Returns
    * `{:ok, results}` - List of import results for each order
    * `{:error, reason}` - Error details if import fails
  """
  @spec run(any(), String.t() | nil) :: {:ok, list()} | {:error, any()}
  def run(args, base_url \\ nil)
  
  def run(file_path, base_url) when is_binary(file_path) do
    initialize_dependencies()
    
    case import_csv_file(file_path, base_url) do
      {:ok, results} -> 
        display_import_summary(results)
        {:ok, results}
        
      {:error, reason} -> 
        display_error_message(reason)
        {:error, reason}
    end
  end

  def run(_args, _base_url) do
    display_usage_instructions()
    {:error, :invalid_arguments}
  end

  # Private implementation functions

  defp initialize_dependencies do
    Application.ensure_all_started(:req)
  end

  defp import_csv_file(file_path, base_url) do
    IO.puts("Starting import of #{file_path}")

    with {:ok, _content} <- read_and_validate_file(file_path),
         parsed_orders <- parse_csv_data(file_path),
         results <- process_orders(parsed_orders, base_url) do
      {:ok, results}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp read_and_validate_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        IO.puts("Successfully read file with #{byte_size(content)} bytes")
        {:ok, content}
        
      {:error, reason} ->
        {:error, "Failed to read file: #{inspect(reason)}"}
    end
  end

  defp parse_csv_data(file_path) do
    CsvParser.parse_file(file_path)
  end

  defp process_orders(orders, base_url) do
    orders
    |> Enum.with_index()
    |> Enum.map(&process_single_order(&1, base_url))
  end

  defp process_single_order({order_data, index}, base_url) do
    case SpreadConnectClient.create_order(order_data, base_url) do
      {:ok, response} ->
        {:ok, {index, response}}

      {:error, error} ->
        display_order_error(index, error)
        {:error, {index, error}}
    end
  end

  defp display_order_error(index, error) do
    IO.puts("Error processing order #{index + 1}: #{inspect(error)}")
  end

  defp display_import_summary(results) do
    {successful_orders, failed_orders} = Enum.split_with(results, &match?({:ok, _}, &1))
    
    IO.puts("\n" <> build_summary_message(successful_orders, failed_orders))
  end

  defp build_summary_message(successful_orders, failed_orders) do
    """
    Import Summary:
    Successfully processed: #{length(successful_orders)} records
    Failed to process: #{length(failed_orders)} records
    """
  end

  defp display_error_message(reason) do
    IO.puts("Import failed: #{reason}")
  end

  defp display_usage_instructions do
    IO.puts("""
    Usage: mix import.csv <file_path>
    
    Example:
      mix import.csv /path/to/orders.csv
    """)
  end
end