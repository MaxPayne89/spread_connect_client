# SpreadConnectClient

[![GitHub](https://img.shields.io/badge/GitHub-maxPayneSU%2Fspread__connect__client-blue?logo=github)](https://github.com/maxPayneSU/spread_connect_client)

A client library for importing CSV order data and submitting it to the SpreadConnect API. This library provides a convenient mix task for processing CSV files containing order information.

**🚀 Fast Test Suite**: 76 tests run in just 0.3 seconds

## How to Use

### Quick Start

If you just want to import a CSV file to SpreadConnect:

1. **Get your SpreadConnect API token** from your SpreadConnect account
2. **Clone and set up the project** (see [Step-by-Step Guide](#step-by-step-guide) below)
3. **Set your API token**: `export SPREAD_CONNECT_ACCESS_TOKEN="your-token-here"`
4. **Import your CSV**: `mix import.csv path/to/your/orders.csv`

### Step-by-Step Guide

#### Step 1: Get Your SpreadConnect API Credentials

1. Log into your SpreadConnect account
2. Navigate to Account Settings → API Keys
3. Generate a new API token or copy your existing one
4. Keep this token safe - you'll need it for the next step

#### Step 2: Setup the Project

```bash
# Clone the repository
git clone https://github.com/maxPayneSU/spread_connect_client.git
cd spread_connect_client

# Install dependencies (see Prerequisites section for asdf setup)
asdf install
mix deps.get

# Set up your API credentials
export SPREAD_CONNECT_ACCESS_TOKEN="your-actual-api-token-here"

# Or create a .env file (recommended)
cp .env.example .env
# Edit .env and add your real API token
source .env
```

#### Step 3: Prepare Your CSV File

Your CSV file should have these columns (in this exact order):

| Column | Description | Example |
|--------|-------------|---------|
| Order number | Unique order identifier | `ORD-12345` |
| Date created | Order date | `Dec 8, 2024` |
| Time | Order time | `9:15:51 AM` |
| Fulfill by | Fulfillment service | `Spreadconnect` |
| Total order quantity | Number of items | `2` |
| Contact email | Customer email | `customer@example.com` |
| Item | Product name | `Custom T-Shirt` |
| SKU | Product SKU | `TSHIRT-001` |
| Qty | Quantity | `1` |
| Price | Unit price | `19.99` |
| Recipient name | Shipping name | `John Doe` |
| Recipient phone | Phone number | `0152 24260416` |
| Delivery address | Street address | `Main St 123` |
| Delivery city | City | `Berlin` |
| Delivery zip/postal code | ZIP code | `12345` |
| Currency | Currency code | `EUR` |
| Fulfillment service | Must be "Spreadconnect" | `Spreadconnect` |

**Important Notes:**
- Only orders with `Fulfillment service = "Spreadconnect"` will be processed
- Phone numbers in German format (0152...) are automatically converted to international (+49152...)
- Multiple items with the same order number are grouped together

#### Step 4: Run the Import

```bash
# Import your CSV file
mix import.csv path/to/your/orders.csv

# Example
mix import.csv ~/Downloads/shopify_orders.csv
```

#### Step 5: Understanding the Output

The import will show real-time progress:

```
Starting import of ~/Downloads/orders.csv
Successfully read file with 15243 bytes

Processing order ORD-12345... ✓
Processing order ORD-12346... ✓
Processing order ORD-12347... ✗ Error: Invalid phone number format

Import Summary:
Successfully processed: 2 records
Failed to process: 1 records
```

**Success indicators:**
- ✓ Order processed successfully
- Confirmation ID returned from SpreadConnect API
- Order appears in your SpreadConnect dashboard

**Error indicators:**
- ✗ Processing failed with specific error message
- Common errors: invalid data, authentication issues, network problems

### Troubleshooting

#### Common Issues

**"Missing SPREAD_CONNECT_ACCESS_TOKEN"**
- Solution: Set your API token with `export SPREAD_CONNECT_ACCESS_TOKEN="your-token"`
- Or create a `.env` file with your token

**"Unauthorized access"**
- Your API token is invalid or expired
- Check your SpreadConnect account and generate a new token

**"Invalid CSV format" or "Insufficient columns"**
- Your CSV doesn't have the required 52 columns
- Export your orders from your e-commerce platform with all fields
- Ensure the header row matches the expected format

**"No orders to process"**
- Your CSV doesn't contain any rows with `Fulfillment service = "Spreadconnect"`
- Check that your orders are set to use SpreadConnect fulfillment

**Network/connection errors**
- Check your internet connection
- Verify the SpreadConnect API is accessible
- Try again in a few minutes

#### Getting Help

1. **Check the output** - Error messages usually explain the problem
2. **Verify your CSV format** - Ensure all required columns are present
3. **Test with a small file** - Try importing just 1-2 orders first
4. **Check your API credentials** - Make sure your token is valid

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

## Technical Details

### Configuration

The client uses configurable settings via environment variables:

- **`SPREAD_CONNECT_ACCESS_TOKEN`** (required): Your SpreadConnect API access token
- **`SPREAD_CONNECT_BASE_URL`** (optional): API endpoint override (defaults to `https://api.spreadconnect.app`)

### Default Behavior

- **Shipping method**: STANDARD
- **Phone number format**: Automatically converts German local format (0152...) to international (+49152...)
- **Order grouping**: Multiple line items with the same order number are consolidated into a single order
- **Data filtering**: Only processes orders where `Fulfillment service = "Spreadconnect"`

### Testing

Run the comprehensive test suite:

```bash
mix test  # Runs all 76 tests in ~0.3 seconds
```

The test suite includes:
- Unit tests for CSV parsing
- Integration tests for API communication
- Performance tests for concurrent processing
- Mock HTTP server tests using Bypass

## Contributing

This project uses:
- **Elixir 1.18** with OTP 27
- **Mix** for build management
- **ExUnit** for testing
- **NimbleCSV** for CSV parsing
- **Req** for HTTP communication

See `CLAUDE.md` for detailed development guidance.

## License

This project is available as open source under the terms of the MIT License.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for detailed release notes and version history.
