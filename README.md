# SpreadConnectClient

A client library for importing CSV order data and submitting it to the SpreadConnect API. This library provides a convenient mix task for processing CSV files containing order information.

## Usage

### CSV Import Task

The library provides a mix task for importing CSV files and submitting the data to SpreadConnect:

### CSV File Format

Your CSV file should contain the following columns (in order):
* Order number
* Email
* SKU
* Quantity
* Price
* Recipient information (name, phone, company)
* Delivery address details
* Billing address details
* Currency

### Example Output

When running the import task, you'll see progress information and a final summary:

### Understanding Results

The task provides real-time feedback:
* Each row processing is tracked
* Failed rows are reported with specific error messages
* A final summary shows successful and failed imports
* Successful imports will receive a confirmation ID from the API

Example output:

```
Starting import of test/fixtures/multiple_items.csv
Successfully read file with 4718 bytes
Error processing row 1: %{status: 401, body: %{"error" => "Unauthorized access"}}
Error processing row 2: %{status: 401, body: %{"error" => "Unauthorized access"}}

Import Summary:
Successfully processed: 0 records
Failed to process: 2 records
```

### Error Handling

The task handles various error scenarios:
* Invalid CSV format
* API connection issues
* Server-side validation errors
* Missing or malformed data

Each error is logged with the specific row number for easy troubleshooting.

## Configuration

The client uses the following default settings:
* API Base URL: https://api.spreadconnect.app
* Default shipping method: STANDARD
* Phone number format: International (automatically converts local formats)
