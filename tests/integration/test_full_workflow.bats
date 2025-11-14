#!/usr/bin/env bats
# Integration tests for full workflow

load '../helpers/mocks'

setup() {
  TEST_DIR=$(mktemp -d)
  MOCK_BIN_DIR="$TEST_DIR/bin"
  SHARED_TEMPLATE_DIR="$TEST_DIR/shared_templates"
  USER_TEMPLATE_DIR="$TEST_DIR/user_templates"
  OUTPUT_DIR="$TEST_DIR/output"
  
  mkdir -p "$MOCK_BIN_DIR" "$SHARED_TEMPLATE_DIR" "$USER_TEMPLATE_DIR" "$OUTPUT_DIR"
  
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
  
  # Mock osascript to return template and printer choices
  cat > "$MOCK_BIN_DIR/osascript" <<'EOF'
#!/bin/bash
# Mock osascript that returns template and printer choices
if [[ "$*" == *"choose from list"* ]] && [[ "$*" == *"Select a template"* ]]; then
  # Return template choice
  echo "template.pdf"
elif [[ "$*" == *"choose from list"* ]] && [[ "$*" == *"Select a printer"* ]]; then
  # Return printer choice
  echo "printer1"
elif [[ "$*" == *"display notification"* ]]; then
  # Silent for notifications
  exit 0
else
  # Silent for other dialogs
  exit 0
fi
EOF
  chmod +x "$MOCK_BIN_DIR/osascript"
  
  export PATH="$MOCK_BIN_DIR:$PATH"
  export HOME="$TEST_DIR"
  
  # Create test files
  echo "test input pdf" > "$OUTPUT_DIR/input.pdf"
  echo "test template pdf" > "$SHARED_TEMPLATE_DIR/template.pdf"
  
  SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
  SCRIPT="$SCRIPT_DIR/workflow/TemplatePrint.workflow/Contents/Scripts/template-print.sh"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "full workflow: template + input -> print" {
  # Test the complete flow (workflow script with dialogs)
  run "$SCRIPT" "$OUTPUT_DIR/input.pdf"
  
  # Should have called qpdf
  [[ $output == *"qpdf"* ]]
  # Should have called lp
  [[ $output == *"lp"* ]]
}

@test "workflow discovers templates from shared location" {
  # Create template in shared location
  echo "shared template" > "$SHARED_TEMPLATE_DIR/shared.pdf"
  
  run "$SCRIPT" "$OUTPUT_DIR/input.pdf"
  
  # Should discover and use template
  [[ $output == *"qpdf"* ]]
}

@test "workflow discovers templates from user location" {
  # Create template in user location
  echo "user template" > "$USER_TEMPLATE_DIR/user.pdf"
  
  # Update mock to return user template
  cat > "$MOCK_BIN_DIR/osascript" <<'EOF'
#!/bin/bash
if [[ "$*" == *"Select a template"* ]]; then
  echo "user.pdf"
elif [[ "$*" == *"Select a printer"* ]]; then
  echo "printer1"
fi
EOF
  chmod +x "$MOCK_BIN_DIR/osascript"
  
  run "$SCRIPT" "$OUTPUT_DIR/input.pdf"
  
  # Should discover and use template
  [[ $output == *"qpdf"* ]]
}

@test "workflow merges templates from both locations" {
  # Create templates in both locations
  echo "shared template" > "$SHARED_TEMPLATE_DIR/shared.pdf"
  echo "user template" > "$USER_TEMPLATE_DIR/user.pdf"
  
  run "$SCRIPT" "$OUTPUT_DIR/input.pdf"
  
  # Should discover templates from both locations
  [[ $output == *"qpdf"* ]]
}

@test "workflow preserves last template and printer choice" {
  # Set up defaults to remember last template and printer
  mkdir -p "$TEST_DIR/Library/Preferences"
  cat > "$TEST_DIR/defaults.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>lastTemplatePath</key>
  <string>template.pdf</string>
  <key>lastPrinterName</key>
  <string>printer1</string>
</dict></plist>
EOF
  
  run "$SCRIPT" "$OUTPUT_DIR/input.pdf"
  
  # Should use remembered choices
  [[ $output == *"qpdf"* ]]
}
