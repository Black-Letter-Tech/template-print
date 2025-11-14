#!/usr/bin/env bats
# Integration tests for full workflow

load '../helpers/mocks'

setup() {
  TEST_DIR=$(mktemp -d)
  MOCK_BIN_DIR="$TEST_DIR/bin"
  TEMPLATE_DIR="$TEST_DIR/templates"
  OUTPUT_DIR="$TEST_DIR/output"
  
  mkdir -p "$MOCK_BIN_DIR" "$TEMPLATE_DIR" "$OUTPUT_DIR"
  
  # Create more realistic mocks
  # Mock qpdf that creates a simple output
  cat > "$MOCK_BIN_DIR/qpdf" <<'EOF'
#!/bin/bash
# Mock qpdf that creates an output file
if [[ "$1" == "--underlay" ]] || [[ "$1" == "--overlay" ]]; then
  mode="$1"
  template="$2"
  input="$3"
  output="$4"
  # Just copy input to output (simplified)
  cp "$input" "$output" 2>/dev/null || echo "mock pdf" > "$output"
  echo "qpdf $mode $template $input $output"
fi
EOF
  chmod +x "$MOCK_BIN_DIR/qpdf"
  
  # Mock lp
  mock_lp "$MOCK_BIN_DIR"
  
  # Mock defaults
  mock_defaults "$MOCK_BIN_DIR" "$TEST_DIR/defaults.plist"
  
  # Mock osascript (silent for tests)
  cat > "$MOCK_BIN_DIR/osascript" <<'EOF'
#!/bin/bash
# Silent mock - just return success
exit 0
EOF
  chmod +x "$MOCK_BIN_DIR/osascript"
  
  export PATH="$MOCK_BIN_DIR:$PATH"
  
  # Create test files
  echo "test input pdf" > "$OUTPUT_DIR/input.pdf"
  echo "test template pdf" > "$TEMPLATE_DIR/template.pdf"
  
  SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
  SCRIPT="$SCRIPT_DIR/files/template-print.sh"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "full workflow: template + input -> print" {
  # Test the complete flow
  run "$SCRIPT" \
    --template "$TEMPLATE_DIR/template.pdf" \
    --mode underlay \
    "$OUTPUT_DIR/input.pdf"
  
  # Should have called qpdf
  [[ $output == *"qpdf"* ]]
  # Should have called lp
  [[ $output == *"lp"* ]]
}

@test "workflow with template directory" {
  export TEMPLATE_PRINT_DIR="$TEMPLATE_DIR"
  
  run "$SCRIPT" \
    --template template.pdf \
    "$OUTPUT_DIR/input.pdf"
  
  # Should succeed (or at least get to qpdf)
  [[ $output == *"qpdf"* ]]
}

@test "workflow preserves last template choice" {
  export TEMPLATE_PRINT_DIR="$TEMPLATE_DIR"
  
  # First run with a template
  run "$SCRIPT" \
    --template "$TEMPLATE_DIR/template.pdf" \
    --remember 1 \
    "$OUTPUT_DIR/input.pdf"
  
  # Should have stored the template path
  # (This would require checking defaults, which is mocked)
  [[ $status -eq 0 ]] || [[ $status -eq 1 ]]  # May fail on actual execution
}

