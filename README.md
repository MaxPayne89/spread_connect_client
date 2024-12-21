# SpreadConnectClient

A client library for importing CSV order data and submitting it to the SpreadConnect API. This library provides a convenient mix task for processing CSV files containing order information.

## Prerequisites

### Installing asdf Version Manager

1. Install asdf:

* macOS (with Homebrew):
```bash
brew install asdf
```

Add to your shell configuration file (~/.bashrc, ~/.zshrc, etc.):
```bash
. "$HOME/.asdf/asdf.sh"
. "$HOME/.asdf/completions/asdf.bash"
```

* Windows:
```powershell
# 1. Install Chocolatey if not already installed
# Run in PowerShell as Administrator:
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# 2. Install Git for Windows if not already installed
choco install git

# 3. Install asdf-vm
git clone https://github.com/asdf-vm/asdf.git ~\.asdf --branch v0.13.1
```

Add to your PowerShell profile (~\Documents\PowerShell\Microsoft.PowerShell_profile.ps1):
```powershell
$env:ASDF_DIR = "$env:USERPROFILE\.asdf"
. "$env:ASDF_DIR\asdf.ps1"
```

### Installing Erlang and Elixir

1. Add required plugins:
```bash
asdf plugin add erlang
asdf plugin add elixir
```

2. Install Erlang and Elixir:
In the root of the project directory, run:
```bash
asdf install
```

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
