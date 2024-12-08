defmodule Mix.Tasks.Import.Csv do
  use Mix.Task

  alias SpreadConnectClient.Parser.CsvParser

  @moduledoc """
  Imports data from a CSV file and sends it to SpreadConnect API.

  ## Usage

      mix import.csv path/to/file.csv
  """

  @shortdoc "Import CSV data to SpreadConnect"
  def run([file_path]) do
    IO.puts("Starting import of #{file_path}")

    # Ensure all dependencies are started
    Application.ensure_all_started(:req)

    # For now, just verify we can read the file
    case File.read(file_path) do
      {:ok, content} ->
        IO.puts("Successfully read file with #{byte_size(content)} bytes")
        parsed_data = CsvParser.parse_file(file_path)
        IO.inspect(parsed_data)

      {:error, reason} ->
        IO.puts("Error reading file: #{reason}")
    end
  end

  def run(_) do
    IO.puts("Usage: mix import.csv path/to/file.csv")
  end
end
