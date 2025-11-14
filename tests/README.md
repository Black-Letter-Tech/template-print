# Testing

This directory contains tests for template-print using [bats-core](https://github.com/bats-core/bats-core).

## Setup

Install bats-core:
```bash
brew install bats-core
```

## Running Tests

Run all tests:
```bash
make test
```

Run only unit tests:
```bash
make test-unit
```

Run only integration tests:
```bash
make test-integration
```

Run a specific test file:
```bash
bats tests/unit/test_template_print.bats
```

## Test Structure

- `unit/` - Unit tests for individual components
  - `test_template_print.bats` - Tests for the main script
  - `test_workflow_discovery.bats` - Tests for workflow binary discovery

- `integration/` - Integration tests for full workflows
  - `test_full_workflow.bats` - End-to-end workflow tests

- `fixtures/` - Test data files
  - Sample PDFs (placeholders - replace with real PDFs for better testing)

- `helpers/` - Test helper scripts
  - `mocks.sh` - Mock external commands (qpdf, lp, defaults, osascript)
  - `extract_workflow.sh` - Extract workflow script for testing

## Writing Tests

Tests use bats-core syntax. Example:

```bash
@test "description of test" {
  run command_to_test
  [[ $status -eq 0 ]]
  [[ $output == *"expected"* ]]
}
```

## Mocking External Commands

The test helpers create mock versions of external commands (`qpdf`, `lp`, `defaults`, `osascript`) that can be used in tests. These mocks are placed in a temporary directory and added to `PATH` during test execution.

## Notes

- Tests create temporary directories that are cleaned up after each test
- Mock commands are isolated per test run
- Real PDF files can be added to `fixtures/` for more realistic testing

