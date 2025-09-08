# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2025-01-09

### Added
- Comprehensive test suite with 76 tests covering all functionality
- Environment variable configuration for secure API credentials
- Test-specific HTTP client configuration for improved performance
- Enhanced error handling and logging throughout the application
- Security fixes for safe repository publication

### Changed
- **BREAKING**: Replaced hardcoded API keys with environment variables
  - Now requires `SPREAD_CONNECT_ACCESS_TOKEN` environment variable
  - See README.md for setup instructions
- Optimized test suite performance from 21+ seconds to 0.3 seconds (98.6% improvement)
  - Reduced HTTP retry timeouts for test environment
  - Optimized performance test delays and dataset sizes
  - Re-enabled async execution for isolated tests
- Updated logger configuration to use `:warning` instead of deprecated `:warn`
- Improved maintainability with structured logging and CSV schema extraction

### Fixed
- Logger configuration warnings in test environment
- Race conditions in test suite causing intermittent failures
- Security vulnerability by removing hardcoded API credentials from git history

### Development
- Repository now published on GitHub: https://github.com/maxPayneSU/spread_connect_client
- Enhanced CLAUDE.md with comprehensive development guidance
- Optimized development workflow with faster test feedback

## [0.1.0] - 2024-12-15

### Added
- Initial release of SpreadConnect CSV import library
- CSV parsing with NimbleCSV for RFC4180 compliance
- HTTP client using Req library for API communication
- Mix task for CLI-based CSV imports
- Comprehensive error handling and validation
- Support for multiple order items per order
- Automatic phone number format conversion (German → International)
- JSON key transformation (snake_case → camelCase for API compatibility)

### Features
- Filters CSV data to process only "Spreadconnect" fulfillment service orders
- Groups multiple line items by order number into consolidated orders
- Real-time progress tracking and detailed error reporting
- Mock HTTP server testing with Bypass
- Configurable API endpoints and authentication

[0.2.0]: https://github.com/maxPayneSU/spread_connect_client/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/maxPayneSU/spread_connect_client/releases/tag/v0.1.0