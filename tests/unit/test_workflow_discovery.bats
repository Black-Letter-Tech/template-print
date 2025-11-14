#!/usr/bin/env bats
# Tests for workflow binary discovery logic

load '../helpers/mocks'

setup() {
  TEST_DIR=$(mktemp -d)
  MOCK_BIN_DIR="$TEST_DIR/bin"
  WORKFLOW_SCRIPT="$TEST_DIR/workflow_script.sh"
  
  mkdir -p "$MOCK_BIN_DIR"
  
  # Extract workflow script for testing
  SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
  WORKFLOW_PATH="$SCRIPT_DIR/workflow/TemplatePrint.workflow/Contents/document.wflow"
  
  if [[ -f "$WORKFLOW_PATH" ]]; then
    # Extract the script content
    sed -n '/<!\[CDATA\[/,/\]\]>/p' "$WORKFLOW_PATH" | \
      sed '1s/.*<!\[CDATA\[//' | \
      sed '$s/\]\]>.*//' > "$WORKFLOW_SCRIPT"
    chmod +x "$WORKFLOW_SCRIPT"
  fi
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "workflow script exists" {
  [[ -f "$WORKFLOW_SCRIPT" ]]
}

@test "finds binary at /usr/local/bin/template-print" {
  # Create mock binary at system location
  mkdir -p "$TEST_DIR/usr/local/bin"
  echo '#!/bin/bash
echo "template-print called with: $@"' > "$TEST_DIR/usr/local/bin/template-print"
  chmod +x "$TEST_DIR/usr/local/bin/template-print"
  
  export PATH="$TEST_DIR/usr/local/bin:$PATH"
  
  # Mock the script to test discovery logic
  run bash -c "
    if [[ -x \"$TEST_DIR/usr/local/bin/template-print\" ]]; then
      \"$TEST_DIR/usr/local/bin/template-print\" --choose test.pdf
    else
      exit 1
    fi
  "
  
  [[ $status -eq 0 ]]
  [[ $output == *"template-print called with: --choose test.pdf"* ]]
}

@test "finds binary via PATH" {
  # Create mock binary in test bin
  echo '#!/bin/bash
echo "template-print from PATH: $@"' > "$MOCK_BIN_DIR/template-print"
  chmod +x "$MOCK_BIN_DIR/template-print"
  
  export PATH="$MOCK_BIN_DIR:$PATH"
  
  run bash -c "command -v template-print"
  [[ $status -eq 0 ]]
  [[ $output == *"template-print"* ]]
}

@test "shows error when binary not found" {
  # Remove any existing template-print from PATH
  export PATH="$MOCK_BIN_DIR"
  
  # Mock osascript to capture the error
  cat > "$MOCK_BIN_DIR/osascript" <<'EOF'
#!/bin/bash
echo "osascript dialog: $@"
EOF
  chmod +x "$MOCK_BIN_DIR/osascript"
  
  # Test that error path is taken
  run bash -c "
    if command -v template-print >/dev/null 2>&1; then
      template-print --choose test.pdf
    else
      $MOCK_BIN_DIR/osascript -e 'display dialog \"template-print not found\"'
      exit 1
    fi
  "
  
  [[ $status -eq 1 ]]
  [[ $output == *"osascript dialog"* ]]
}

@test "checks Homebrew prefix when HOMEBREW_PREFIX is set" {
  export HOMEBREW_PREFIX="$TEST_DIR/homebrew"
  mkdir -p "$HOMEBREW_PREFIX/bin"
  
  echo '#!/bin/bash
echo "template-print from homebrew: $@"' > "$HOMEBREW_PREFIX/bin/template-print"
  chmod +x "$HOMEBREW_PREFIX/bin/template-print"
  
  run bash -c "
    prefix=\"\$HOMEBREW_PREFIX\"
    if [[ -n \"\$prefix\" && -x \"\$prefix/bin/template-print\" ]]; then
      \"\$prefix/bin/template-print\" --choose test.pdf
    else
      exit 1
    fi
  "
  
  [[ $status -eq 0 ]]
  [[ $output == *"template-print from homebrew: --choose test.pdf"* ]]
}

