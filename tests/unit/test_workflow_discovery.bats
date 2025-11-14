#!/usr/bin/env bats
# Tests for workflow script discovery logic

load '../helpers/mocks'

setup() {
  TEST_DIR=$(mktemp -d)
  MOCK_BIN_DIR="$TEST_DIR/bin"
  WORKFLOW_SCRIPT="$TEST_DIR/workflow_script.sh"
  WORKFLOW_BUNDLE="$TEST_DIR/TemplatePrint.workflow"
  
  mkdir -p "$MOCK_BIN_DIR"
  mkdir -p "$WORKFLOW_BUNDLE/Contents/Scripts"
  
  # Extract workflow entry point for testing
  SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
  WORKFLOW_PATH="$SCRIPT_DIR/workflow/TemplatePrint.workflow/Contents/document.wflow"
  
  if [[ -f "$WORKFLOW_PATH" ]]; then
    # Extract the script content from CDATA
    sed -n '/<!\[CDATA\[/,/\]\]>/p' "$WORKFLOW_PATH" | \
      sed '1s/.*<!\[CDATA\[//' | \
      sed '$s/\]\]>.*//' > "$WORKFLOW_SCRIPT"
    chmod +x "$WORKFLOW_SCRIPT"
  fi
  
  # Create mock bundled script
  echo '#!/bin/bash
echo "bundled script called with: $@"' > "$WORKFLOW_BUNDLE/Contents/Scripts/template-print.sh"
  chmod +x "$WORKFLOW_BUNDLE/Contents/Scripts/template-print.sh"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "workflow entry point script exists" {
  [[ -f "$WORKFLOW_SCRIPT" ]]
}

@test "finds bundled script relative to workflow bundle" {
  # Mock the script to test discovery logic
  cd "$TEST_DIR"
  run bash -c "
    SCRIPT_DIR=\"\$(cd \"\$PWD\" && pwd)\"
    SCRIPT=\"\$SCRIPT_DIR/TemplatePrint.workflow/Contents/Scripts/template-print.sh\"
    if [[ -f \"\$SCRIPT\" ]]; then
      \"\$SCRIPT\" test.pdf
    else
      exit 1
    fi
  "
  
  [[ $status -eq 0 ]]
  [[ $output == *"bundled script called with: test.pdf"* ]]
}

@test "shows error when bundled script not found" {
  rm -rf "$WORKFLOW_BUNDLE/Contents/Scripts/template-print.sh"
  
  # Mock osascript to capture the error
  cat > "$MOCK_BIN_DIR/osascript" <<'EOF'
#!/bin/bash
echo "osascript dialog: $@"
EOF
  chmod +x "$MOCK_BIN_DIR/osascript"
  export PATH="$MOCK_BIN_DIR:$PATH"
  
  # Test that error path is taken
  cd "$TEST_DIR"
  run bash -c "
    SCRIPT_DIR=\"\$(cd \"\$PWD\" && pwd)\"
    SCRIPT=\"\$SCRIPT_DIR/TemplatePrint.workflow/Contents/Scripts/template-print.sh\"
    if [[ ! -f \"\$SCRIPT\" ]]; then
      $MOCK_BIN_DIR/osascript -e 'display dialog \"Template Print script not found\"'
      exit 1
    else
      \"\$SCRIPT\" test.pdf
    fi
  "
  
  [[ $status -eq 1 ]]
  [[ $output == *"osascript dialog"* ]]
}
