#!/usr/bin/env bash
# Mock helpers for testing

# Create a mock binary that can be used in tests
create_mock_binary() {
  local name="$1"
  local script="$2"
  local bin_dir="$3"
  
  mkdir -p "$bin_dir"
  cat > "$bin_dir/$name" <<EOF
#!/usr/bin/env bash
$script
EOF
  chmod +x "$bin_dir/$name"
}

# Mock qpdf that just echoes the command
mock_qpdf() {
  local bin_dir="$1"
  create_mock_binary "qpdf" 'echo "qpdf $@"' "$bin_dir"
}

# Mock lp that just echoes the command
mock_lp() {
  local bin_dir="$1"
  create_mock_binary "lp" 'echo "lp $@"' "$bin_dir"
}

# Mock defaults that stores/retrieves from a temp file
mock_defaults() {
  local bin_dir="$1"
  local defaults_file="$2"
  
  cat > "$bin_dir/defaults" <<MOCKEOF
#!/usr/bin/env bash
local_file="${MOCK_DEFAULTS_FILE:-$defaults_file}"
case "\$1" in
  write)
    # Simple key-value storage in a file
    domain="\$2"
    key="\$3"
    value="\$4"
    mkdir -p "\$(dirname "\$local_file")"
    if [[ ! -f "\$local_file" ]]; then
      echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > "\$local_file"
      echo "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">" >> "\$local_file"
      echo "<plist version=\"1.0\"><dict></dict></plist>" >> "\$local_file"
    fi
    # For simplicity, just echo the operation
    echo "defaults write \$domain \$key \$value" >> "\$local_file"
    ;;
  read)
    domain="\$2"
    key="\$3"
    # Try to read from our temp file, or return empty
    if [[ -f "\$local_file" ]]; then
      grep -o "defaults write \$domain \$key [^ ]*" "\$local_file" | tail -1 | awk '{print \$5}' || echo ""
    else
      echo ""
    fi
    ;;
  *)
    echo "defaults \$@"
    ;;
esac
MOCKEOF
  chmod +x "$bin_dir/defaults"
  export MOCK_DEFAULTS_FILE="$defaults_file"
}

# Mock osascript that just echoes
mock_osascript() {
  local bin_dir="$1"
  create_mock_binary "osascript" 'echo "osascript $@"' "$bin_dir"
}

# Clean up mock binaries
cleanup_mocks() {
  local bin_dir="$1"
  rm -rf "$bin_dir"
}

# Extract workflow script for testing
extract_workflow_script() {
  local workflow_path="$1"
  local output_path="$2"
  
  # Extract the shell script from the .wflow bundle
  if [[ -f "$workflow_path" ]]; then
    # The script is in the COMMAND_STRING CDATA section
    # Use a simple extraction method
    grep -A 1000 'COMMAND_STRING' "$workflow_path" | \
      sed -n '/<!\[CDATA\[/,/\]\]>/p' | \
      sed 's/<!\[CDATA\[//' | \
      sed 's/\]\]>//' | \
      head -n -1 > "$output_path"
  fi
}

