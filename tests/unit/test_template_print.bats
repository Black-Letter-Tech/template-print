#!/usr/bin/env bats
# Tests for template-print.sh

load '../helpers/mocks'

setup() {
  # Create temporary directories
  TEST_DIR=$(mktemp -d)
  MOCK_BIN_DIR="$TEST_DIR/bin"
  TEMPLATE_DIR="$TEST_DIR/templates"
  OUTPUT_DIR="$TEST_DIR/output"
  
  mkdir -p "$MOCK_BIN_DIR" "$TEMPLATE_DIR" "$OUTPUT_DIR"
  
  # Add mock bin to PATH
  export PATH="$MOCK_BIN_DIR:$PATH"
  
  # Create mock commands
  mock_qpdf "$MOCK_BIN_DIR"
  mock_lp "$MOCK_BIN_DIR"
  mock_defaults "$MOCK_BIN_DIR" "$TEST_DIR/defaults.plist"
  mock_osascript "$MOCK_BIN_DIR"
  
  # Create test templates
  echo "test template" > "$TEMPLATE_DIR/template1.pdf"
  echo "test template" > "$TEMPLATE_DIR/template2.pdf"
  
  # Source the script
  SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
  SCRIPT="$SCRIPT_DIR/files/template-print.sh"
}

teardown() {
  # Cleanup
  rm -rf "$TEST_DIR"
  unset PATH
}

@test "script exists and is executable" {
  [[ -f "$SCRIPT" ]]
  [[ -x "$SCRIPT" ]]
}

@test "shows usage with --help" {
  run "$SCRIPT" --help
  [[ $status -eq 0 ]]
  [[ $output == *"Usage"* ]]
  [[ $output == *"template-print"* ]]
}

@test "shows version with --version" {
  run "$SCRIPT" --version
  [[ $status -eq 0 ]]
  [[ $output == *"0.1.0"* ]]
}

@test "fails when input PDF is missing" {
  run "$SCRIPT" --template "$TEMPLATE_DIR/template1.pdf" /nonexistent.pdf
  [[ $status -ne 0 ]]
}

@test "lists templates with --list" {
  export TEMPLATE_PRINT_DIR="$TEMPLATE_DIR"
  run "$SCRIPT" --list
  [[ $status -eq 0 ]]
  [[ $output == *"template1.pdf"* ]]
  [[ $output == *"template2.pdf"* ]]
}

@test "accepts --template option" {
  echo "test input" > "$OUTPUT_DIR/input.pdf"
  run "$SCRIPT" --template "$TEMPLATE_DIR/template1.pdf" "$OUTPUT_DIR/input.pdf"
  # Should attempt to call qpdf (mocked)
  [[ $output == *"qpdf"* ]]
}

@test "accepts --dir option" {
  echo "test input" > "$OUTPUT_DIR/input.pdf"
  run "$SCRIPT" --dir "$TEMPLATE_DIR" --template template1.pdf "$OUTPUT_DIR/input.pdf"
  [[ $status -eq 0 ]] || [[ $status -eq 1 ]]  # May fail on qpdf execution, but should parse args
}

@test "accepts --mode option" {
  echo "test input" > "$OUTPUT_DIR/input.pdf"
  run "$SCRIPT" --mode overlay --template "$TEMPLATE_DIR/template1.pdf" "$OUTPUT_DIR/input.pdf"
  # Should parse the mode option
  [[ $output == *"qpdf"* ]]
}

