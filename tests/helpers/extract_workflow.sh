#!/usr/bin/env bash
# Extract the shell script from the Automator workflow bundle

WORKFLOW_PATH="${1:-../workflow/TemplatePrint.workflow/Contents/document.wflow}"
OUTPUT_PATH="${2:-../tests/fixtures/workflow_script.sh}"

if [[ ! -f "$WORKFLOW_PATH" ]]; then
  echo "Error: Workflow file not found: $WORKFLOW_PATH" >&2
  exit 1
fi

# Extract the script from the CDATA section
# The script is between <![CDATA[ and ]]>
sed -n '/<!\[CDATA\[/,/\]\]>/p' "$WORKFLOW_PATH" | \
  sed '1s/.*<!\[CDATA\[//' | \
  sed '$s/\]\]>.*//' > "$OUTPUT_PATH"

chmod +x "$OUTPUT_PATH"
echo "Extracted workflow script to: $OUTPUT_PATH"

