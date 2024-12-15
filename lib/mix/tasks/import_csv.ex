defmodule Mix.Tasks.Import.Csv do
  use Mix.Task

  alias SpreadConnectClient.Parser.CsvParser
  alias SpreadConnectClient.Client.SpreadConnectClient

  @moduledoc """
  Imports data from a CSV file and sends it to SpreadConnect API.

  ## Usage

      mix import.csv path/to/file.csv
  """

  @shortdoc "Import CSV data to SpreadConnect"
  def run(file_path, base_url) do
    IO.puts("Starting import of #{file_path}")
    Application.ensure_all_started(:req)

    with {:ok, content} <- File.read(file_path),
         _ <- IO.puts("Successfully read file with #{byte_size(content)} bytes"),
         parsed_data <- CsvParser.parse_file(file_path) do
      results =
        parsed_data
        |> Enum.with_index()
        |> Enum.map(fn {order_data, index} ->
          case SpreadConnectClient.create_order(order_data, base_url) do
            {:ok, response} ->
              {:ok, {index, response}}

            {:error, error} ->
              IO.puts("Error processing row #{index + 1}: #{inspect(error)}")
              {:error, {index, error}}
          end
        end)

      # Summarize results
      {success, failures} = Enum.split_with(results, &match?({:ok, _}, &1))

      IO.puts("\nImport Summary:")
      IO.puts("Successfully processed: #{length(success)} records")
      IO.puts("Failed to process: #{length(failures)} records")

      {:ok, results}
    else
      {:error, reason} ->
        IO.puts("Error reading file: #{reason}")
        {:error, reason}
    end
  end

  def run(_) do
    IO.puts("Usage: mix import.csv path/to/file.csv")
  end
end
