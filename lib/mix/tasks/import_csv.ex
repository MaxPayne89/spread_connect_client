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
  require Logger

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
    Logger.info("Starting CSV import", 
      file_path: file_path, 
      base_url: base_url || "default"
    )

    with {:ok, :validated} <- read_and_validate_file(file_path),
         {:ok, parsed_orders} <- parse_csv_data(file_path),
         results <- process_orders(parsed_orders, base_url) do
      {:ok, results}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp read_and_validate_file(file_path) do
    case File.stat(file_path) do
      {:ok, %{size: size, access: access}} when access in [:read, :read_write] ->
        Logger.info("Processing CSV file", 
          file_path: file_path,
          file_size_bytes: size, 
          access_mode: access
        )
        {:ok, :validated}
        
      {:ok, %{access: access}} ->
        {:error, "File not readable: access is #{access}"}
        
      {:error, reason} ->
        {:error, "Failed to access file: #{inspect(reason)}"}
    end
  end

  defp parse_csv_data(file_path) do
    case CsvParser.parse_file(file_path) do
      {:error, reason} -> {:error, reason}
      orders when is_list(orders) -> {:ok, orders}
    end
  end

  defp process_orders(orders, base_url) do
    orders
    |> Stream.with_index()
    |> Task.async_stream(&process_single_order(&1, base_url), 
                          max_concurrency: 10,
                          timeout: 30_000,
                          on_timeout: :kill_task)
    |> Enum.map(fn
      {:ok, result} -> result
      {:exit, :timeout} -> {:error, {-1, %{status: 408, body: %{"error" => "Request timeout"}}}}
      {:exit, reason} -> {:error, {-1, %{status: 500, body: %{"error" => "Task failed: #{inspect(reason)}"}}}}
    end)
  end

  defp process_single_order({order_data, index}, base_url) do
    case SpreadConnectClient.create_order(order_data, base_url) do
      {:ok, response} ->
        {:ok, {index, response}}

      {:error, error} ->
        display_order_error(index, error)
        {:error, {index, error}}
    end
  rescue
    exception ->
      error_response = %{status: 500, body: %{"error" => Exception.message(exception)}}
      display_order_error(index, error_response)
      {:error, {index, error_response}}
  end

  defp display_order_error(index, error) do
    # Log structured error without exposing sensitive order data
    Logger.error("Order processing failed", 
      order_index: index + 1,
      error_status: error[:status] || "unknown",
      error_type: get_error_type(error)
    )
    
    # Still display error for CLI users, but sanitized
    IO.puts("Error processing order #{index + 1}: #{get_sanitized_error_message(error)}")
  end
  
  defp get_error_type(error) when is_map(error) do
    cond do
      error[:status] in [400, 401, 403] -> "authentication_error"
      error[:status] in [422, 400] -> "validation_error"  
      error[:status] in [500, 502, 503] -> "server_error"
      error[:status] == 429 -> "rate_limit_error"
      true -> "unknown_error"
    end
  end
  defp get_error_type(_), do: "unknown_error"
  
  defp get_sanitized_error_message(error) when is_map(error) do
    case error do
      %{body: %{"error" => message}} when is_binary(message) -> message
      %{status: status} -> "HTTP #{status} error"
      _ -> "Processing error"
    end
  end
  defp get_sanitized_error_message(_), do: "Processing error"

  defp display_import_summary(results) do
    {successful_orders, failed_orders} = Enum.split_with(results, &match?({:ok, _}, &1))
    
    Logger.info("Import completed", 
      successful_count: length(successful_orders),
      failed_count: length(failed_orders),
      total_count: length(results)
    )
    
    # Also display summary for CLI users
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
    Logger.error("CSV import failed", 
      reason: reason,
      error_type: "import_failure"
    )
    
    # Still display error for CLI users  
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