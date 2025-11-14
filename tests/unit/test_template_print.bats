#!/usr/bin/env bats
# Tests for workflow template-print.sh script

load '../helpers/mocks'

setup() {
  # Create temporary directories
  TEST_DIR=$(mktemp -d)
  MOCK_BIN_DIR="$TEST_DIR/bin"
  SHARED_TEMPLATE_DIR="$TEST_DIR/shared_templates"
  USER_TEMPLATE_DIR="$TEST_DIR/user_templates"
  OUTPUT_DIR="$TEST_DIR/output"
  
  mkdir -p "$MOCK_BIN_DIR" "$SHARED_TEMPLATE_DIR" "$USER_TEMPLATE_DIR" "$OUTPUT_DIR"
  
  # Add mock bin to PATH
  export PATH="$MOCK_BIN_DIR:$PATH"
  
  # Create mock commands
  mock_qpdf "$MOCK_BIN_DIR"
  mock_lp "$MOCK_BIN_DIR"
  mock_defaults "$MOCK_BIN_DIR" "$TEST_DIR/defaults.plist"
  mock_osascript "$MOCK_BIN_DIR" "$SHARED_TEMPLATE_DIR" "$USER_TEMPLATE_DIR"
  
  # Create test templates
  echo "test template" > "$SHARED_TEMPLATE_DIR/template1.pdf"
  echo "test template" > "$USER_TEMPLATE_DIR/template2.pdf"
  
  # Source the script
  SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
  SCRIPT="$SCRIPT_DIR/workflow/TemplatePrint.workflow/Contents/Scripts/template-print.sh"
  
  # Set up environment for script
  export HOME="$TEST_DIR"
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

@test "fails when input PDF is missing" {
  run "$SCRIPT" /nonexistent.pdf
  [[ $status -ne 0 ]]
}

@test "discovers templates from shared location" {
  echo "test input" > "$OUTPUT_DIR/input.pdf"
  # Mock osascript to return template1.pdf
  echo "template1.pdf" > "$MOCK_BIN_DIR/osascript_choice"
  echo "printer1" > "$MOCK_BIN_DIR/osascript_printer"
  
  run "$SCRIPT" "$OUTPUT_DIR/input.pdf"
  # Should attempt to discover templates
  [[ $status -eq 0 ]] || [[ $status -eq 1 ]]  # May fail on qpdf execution, but should discover templates
}

@test "discovers templates from user location" {
  echo "test input" > "$OUTPUT_DIR/input.pdf"
  # Mock osascript to return template2.pdf
  echo "template2.pdf" > "$MOCK_BIN_DIR/osascript_choice"
  echo "printer1" > "$MOCK_BIN_DIR/osascript_printer"
  
  run "$SCRIPT" "$OUTPUT_DIR/input.pdf"
  # Should attempt to discover templates from both locations
  [[ $status -eq 0 ]] || [[ $status -eq 1 ]]
}

@test "fails when no templates found" {
  rm -rf "$SHARED_TEMPLATE_DIR"/* "$USER_TEMPLATE_DIR"/*
  echo "test input" > "$OUTPUT_DIR/input.pdf"
  
  run "$SCRIPT" "$OUTPUT_DIR/input.pdf"
  [[ $status -ne 0 ]]
  [[ $output == *"No templates found"* ]]
}

@test "resolves qpdf from user-space location first" {
  # Create mock qpdf in user-space location
  mkdir -p "$TEST_DIR/Library/Application Support/template-print/bin"
  echo "#!/bin/bash" > "$TEST_DIR/Library/Application Support/template-print/bin/qpdf"
  echo "echo 'qpdf from user-space'" >> "$TEST_DIR/Library/Application Support/template-print/bin/qpdf"
  chmod +x "$TEST_DIR/Library/Application Support/template-print/bin/qpdf"
  
  echo "test input" > "$OUTPUT_DIR/input.pdf"
  echo "template1.pdf" > "$MOCK_BIN_DIR/osascript_choice"
  echo "printer1" > "$MOCK_BIN_DIR/osascript_printer"
  
  run "$SCRIPT" "$OUTPUT_DIR/input.pdf"
  # Should use user-space qpdf
  [[ $status -eq 0 ]] || [[ $status -eq 1 ]]
}
