#!/bin/bash
set -euo pipefail

# Ensure we're using bash (not sh) - macOS default bash is 3.2, but we need basic array support
if [[ -z "${BASH_VERSION:-}" ]]; then
  echo "Error: This script requires bash" >&2
  exit 1
fi

# Template Print workflow script
# Called by macOS Print Services with PDF file path as $1

DEFAULTS_DOMAIN="com.blacklettertech.template-print"
TEMPLATE_KEY="lastTemplatePath"
PRINTER_KEY="lastPrinterName"
SHARED_TEMPLATE_DIR="/Users/Shared/Shared PDF Templates"
USER_TEMPLATE_DIR="${HOME}/My PDF Templates"
MODE="underlay"  # Always use underlay
DEBUG_LOG="${HOME}/Library/Logs/template-print-debug.log"

escape_osascript() {
  local input="$1"
  input="${input//\\/\\\\}"
  input="${input//$'\n'/\\n}"
  input="${input//\"/\\\"}"
  printf '%s' "$input"
}

alert() {
  local message="$1"
  if command -v osascript >/dev/null 2>&1; then
    /usr/bin/osascript -e "display dialog \"$(escape_osascript "$message")\" with title \"Template Print\" buttons {\"OK\"} default button \"OK\" with icon caution" >/dev/null 2>&1 || true
  fi
}

fatal() {
  local message="$1"
  printf 'Template Print: %s\n' "${message}" >&2
  alert "${message}"
  exit "${2:-1}"
}

detect_program() {
  local candidate
  for candidate in "$@"; do
    if [[ -x "${candidate}" ]]; then
      printf '%s' "${candidate}"
      return 0
    fi
    if command -v "${candidate}" >/dev/null 2>&1; then
      command -v "${candidate}"
      return 0
    fi
  done
  return 1
}

resolve_qpdf() {
  local qpdf
  echo "Resolving qpdf..." >> "$DEBUG_LOG" 2>&1
  # Check user-space bundled qpdf first
  if qpdf=$(detect_program \
    "${HOME}/Library/Application Support/template-print/bin/qpdf" \
    /opt/homebrew/bin/qpdf \
    /usr/local/bin/qpdf \
    qpdf); then
    echo "qpdf found at: ${qpdf}" >> "$DEBUG_LOG" 2>&1
    printf '%s\n' "${qpdf}"
    return 0
  fi
  echo "ERROR: qpdf not found" >> "$DEBUG_LOG" 2>&1
  return 1
}

remember_template() {
  local path="$1"
  defaults write "${DEFAULTS_DOMAIN}" "${TEMPLATE_KEY}" -string "${path}" >/dev/null 2>&1 || true
}

load_last_template() {
  defaults read "${DEFAULTS_DOMAIN}" "${TEMPLATE_KEY}" 2>/dev/null || true
}

remember_printer() {
  local printer="$1"
  defaults write "${DEFAULTS_DOMAIN}" "${PRINTER_KEY}" -string "${printer}" >/dev/null 2>&1 || true
}

load_last_printer() {
  defaults read "${DEFAULTS_DOMAIN}" "${PRINTER_KEY}" 2>/dev/null || true
}

load_default_printer() {
  local printer
  if printer=$(lpstat -d 2>/dev/null | awk -F': ' 'NR==1 {print $2}'); then
    printf '%s' "${printer}"
    return 0
  fi
  return 1
}

discover_templates() {
  local -a templates=()
  
  echo "Discovering templates..." >> "$DEBUG_LOG" 2>&1
  echo "  Checking shared location: ${SHARED_TEMPLATE_DIR}" >> "$DEBUG_LOG" 2>&1
  
  # Discover from shared location
  if [[ -d "${SHARED_TEMPLATE_DIR}" ]]; then
    while IFS= read -r line; do
      [[ -n "${line}" ]] || continue
      templates+=("${line}")
      echo "  Found in shared: ${line}" >> "$DEBUG_LOG" 2>&1
    done < <(find "${SHARED_TEMPLATE_DIR}" -maxdepth 1 -type f \( -iname '*.pdf' -o -iname '*.PDF' \) -print0 | tr '\0' '\n' | sed '/^$/d' 2>/dev/null || true)
  else
    echo "  Shared location does not exist" >> "$DEBUG_LOG" 2>&1
  fi
  
  echo "  Checking user location: ${USER_TEMPLATE_DIR}" >> "$DEBUG_LOG" 2>&1
  
  # Discover from user location
  if [[ -d "${USER_TEMPLATE_DIR}" ]]; then
    echo "  User location exists, searching for PDFs..." >> "$DEBUG_LOG" 2>&1
    while IFS= read -r line; do
      [[ -n "${line}" ]] || continue
      templates+=("${line}")
      echo "  Found in user: ${line}" >> "$DEBUG_LOG" 2>&1
    done < <(find "${USER_TEMPLATE_DIR}" -maxdepth 1 -type f \( -iname '*.pdf' -o -iname '*.PDF' \) -print0 | tr '\0' '\n' | sed '/^$/d' 2>/dev/null || true)
    echo "  Finished searching user location" >> "$DEBUG_LOG" 2>&1
  else
    echo "  User location does not exist" >> "$DEBUG_LOG" 2>&1
  fi
  
  echo "Before sort/deduplicate, array size: ${#templates[@]}" >> "$DEBUG_LOG" 2>&1
  
  # Sort and deduplicate
  if (( ${#templates[@]} > 0 )); then
    echo "  Sorting and deduplicating..." >> "$DEBUG_LOG" 2>&1
    local temp_file
    temp_file="$(mktemp)" || {
      echo "  ERROR: Failed to create temp file" >> "$DEBUG_LOG" 2>&1
      return 1
    }
    printf '%s\n' "${templates[@]}" | sort -u > "$temp_file"
    echo "  Temp file created: ${temp_file}" >> "$DEBUG_LOG" 2>&1
    echo "  Temp file size: $(stat -f%z "$temp_file" 2>/dev/null || echo "unknown") bytes" >> "$DEBUG_LOG" 2>&1
    
    local -a sorted=()
    if [[ -s "$temp_file" ]]; then
      while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        sorted+=("$line")
        echo "    Read line: $line" >> "$DEBUG_LOG" 2>&1
      done < "$temp_file"
    else
      echo "  WARNING: Temp file is empty" >> "$DEBUG_LOG" 2>&1
    fi
    rm -f "$temp_file"
    if (( ${#sorted[@]} > 0 )); then
      templates=("${sorted[@]}")
    else
      templates=()
    fi
    echo "  Sort/deduplicate complete, new array size: ${#templates[@]}" >> "$DEBUG_LOG" 2>&1
  else
    echo "  No templates to sort" >> "$DEBUG_LOG" 2>&1
  fi
  
  echo "Total templates discovered: ${#templates[@]}" >> "$DEBUG_LOG" 2>&1
  echo "discover_templates() completed" >> "$DEBUG_LOG" 2>&1
  
  # Output templates (one per line) for caller to capture
  printf '%s\n' "${templates[@]}"
}

choose_template() {
  echo "choose_template() called" >> "$DEBUG_LOG" 2>&1
  local -a templates=()
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    templates+=("$line")
  done < <(discover_templates)
  
  echo "Templates array size: ${#templates[@]}" >> "$DEBUG_LOG" 2>&1
  (( ${#templates[@]} > 0 )) || fatal "No templates found. Add PDF templates to:\n${SHARED_TEMPLATE_DIR}\nor\n${USER_TEMPLATE_DIR}"
  
  local last_template
  last_template="$(load_last_template)"
  echo "Last template from defaults: ${last_template:-<none>}" >> "$DEBUG_LOG" 2>&1
  
  local -a display_names=()
  local item
  for item in "${templates[@]}"; do
    local name="${item##*/}"
    display_names+=("${name}")
    echo "  Template: ${name} -> ${item}" >> "$DEBUG_LOG" 2>&1
  done
  
  # Function to find template path by display name (replaces associative array)
  find_template_by_name() {
    local search_name="$1"
    local item
    for item in "${templates[@]}"; do
      if [[ "${item##*/}" == "$search_name" ]]; then
        printf '%s\n' "$item"
        return 0
      fi
    done
    return 1
  }
  
  local default_clause=""
  if [[ -n "${last_template}" ]]; then
    local last_name="${last_template##*/}"
    echo "  Checking if last template '${last_name}' is in list..." >> "$DEBUG_LOG" 2>&1
    if find_template_by_name "${last_name}" >/dev/null 2>&1; then
      default_clause="default items {\"${last_name}\"}"
      echo "  Setting default to: ${last_name}" >> "$DEBUG_LOG" 2>&1
    else
      echo "  Last template not found in current templates" >> "$DEBUG_LOG" 2>&1
    fi
  fi
  
  local quoted_list=""
  local name
  for name in "${display_names[@]}"; do
    local escaped_name="${name//\"/\\\"}"
    if [[ -z "${quoted_list}" ]]; then
      quoted_list="\"${escaped_name}\""
    else
      quoted_list="${quoted_list}, \"${escaped_name}\""
    fi
  done
  
  echo "Display names: ${display_names[*]}" >> "$DEBUG_LOG" 2>&1
  echo "About to show template selection dialog..." >> "$DEBUG_LOG" 2>&1
  echo "AppleScript template list: ${quoted_list}" >> "$DEBUG_LOG" 2>&1
  
  local selection
  selection=$(/usr/bin/osascript <<EOF
set _templates to {${quoted_list}}
set _result to choose from list _templates with prompt "Select a template to apply" ${default_clause} OK button name "Use Template" cancel button name "Cancel"
if _result is false then
  error number -128
end if
item 1 of _result
EOF
  ) || {
    local exit_code=$?
    echo "ERROR: Template selection failed or cancelled (exit code: ${exit_code})" >> "$DEBUG_LOG" 2>&1
    fatal "Template selection cancelled." 1
  }
  
  echo "Template selection returned: ${selection}" >> "$DEBUG_LOG" 2>&1
  
  local chosen
  chosen="$(find_template_by_name "${selection}")"
  [[ -n "${chosen}" ]] || fatal "Unable to resolve chosen template."
  
  echo "Template selected: ${chosen}" >> "$DEBUG_LOG" 2>&1
  remember_template "${chosen}"
  printf '%s\n' "${chosen}"
}

get_available_printers() {
  local -a printers=()
  while IFS= read -r line; do
    [[ -n "${line}" ]] || continue
    printers+=("${line}")
  done < <(lpstat -p 2>/dev/null | awk '/^printer/ {print $2}' || true)
  printf '%s\n' "${printers[@]}"
}

choose_printer() {
  echo "Discovering printers..." >> "$DEBUG_LOG" 2>&1
  local -a printers=()
  while IFS= read -r line; do
    [[ -n "${line}" ]] || continue
    printers+=("${line}")
    echo "  Found printer: ${line}" >> "$DEBUG_LOG" 2>&1
  done < <(get_available_printers)
  
  if (( ${#printers[@]} == 0 )); then
    echo "ERROR: No printers available" >> "$DEBUG_LOG" 2>&1
    fatal "No printers available. Please add a printer in System Settings."
  fi
  
  echo "Total printers found: ${#printers[@]}" >> "$DEBUG_LOG" 2>&1
  
  local last_printer
  last_printer="$(load_last_printer)"
  
  # Validate last printer still exists
  local default_printer=""
  if [[ -n "${last_printer}" ]]; then
    local found=0
    for p in "${printers[@]}"; do
      if [[ "$p" == "$last_printer" ]]; then
        found=1
        break
      fi
    done
    if (( found )); then
      default_printer="${last_printer}"
    fi
  fi
  
  # Fall back to system default if no remembered printer
  if [[ -z "${default_printer}" ]]; then
    if default_printer=$(load_default_printer); then
      :
    else
      default_printer="${printers[0]}"  # Use first available
    fi
  fi
  
  local default_clause=""
  if [[ -n "${default_printer}" ]]; then
    default_clause="default items {\"${default_printer}\"}"
  fi
  
  local quoted_list=""
  local printer
  for printer in "${printers[@]}"; do
    local escaped_printer="${printer//\"/\\\"}"
    if [[ -z "${quoted_list}" ]]; then
      quoted_list="\"${escaped_printer}\""
    else
      quoted_list="${quoted_list}, \"${escaped_printer}\""
    fi
  done
  
  local selection
  selection=$(/usr/bin/osascript <<EOF
set _printers to {${quoted_list}}
set _result to choose from list _printers with prompt "Select a printer" ${default_clause} OK button name "Print" cancel button name "Cancel"
if _result is false then
  error number -128
end if
item 1 of _result
EOF
  ) || fatal "Printer selection cancelled." 1
  
  echo "Printer selected: ${selection}" >> "$DEBUG_LOG" 2>&1
  remember_printer "${selection}"
  printf '%s\n' "${selection}"
}

compose_with_qpdf() {
  local compositor="$1"
  local mode="$2"
  local template="$3"
  local input_pdf="$4"
  local output_pdf="$5"
  
  local flag="--underlay"
  [[ "${mode}" == "overlay" ]] && flag="--overlay"
  
  echo "Composing PDF..." >> "$DEBUG_LOG" 2>&1
  echo "  qpdf: ${compositor}" >> "$DEBUG_LOG" 2>&1
  echo "  mode: ${flag}" >> "$DEBUG_LOG" 2>&1
  echo "  template: ${template}" >> "$DEBUG_LOG" 2>&1
  echo "  input: ${input_pdf}" >> "$DEBUG_LOG" 2>&1
  echo "  output: ${output_pdf}" >> "$DEBUG_LOG" 2>&1
  
  if "${compositor}" "${flag}" "${template}" -- "${input_pdf}" "${output_pdf}" >> "$DEBUG_LOG" 2>&1; then
    echo "  Composition successful" >> "$DEBUG_LOG" 2>&1
  else
    local exit_code=$?
    echo "  ERROR: Composition failed (exit code: ${exit_code})" >> "$DEBUG_LOG" 2>&1
    return ${exit_code}
  fi
}

# Main execution
main() {
  {
    echo "=== template-print.sh Main Function $(date) ==="
    echo "Arguments received: $#"
    i=1
    for arg in "$@"; do
      echo "  [$i] $arg"
      i=$((i + 1))
    done
  } >> "$DEBUG_LOG" 2>&1
  
  # Get PDF file from workflow (automatically passed by macOS Print Services)
  local input_pdf="$1"
  
  {
    echo "Input PDF: ${input_pdf}"
    echo "Input PDF exists: $([ -f "${input_pdf}" ] && echo "yes" || echo "no")"
  } >> "$DEBUG_LOG" 2>&1
  
  [[ -n "${input_pdf}" ]] || fatal "No PDF file provided."
  [[ -f "${input_pdf}" ]] || fatal "PDF file '${input_pdf}' does not exist."
  
  # Resolve qpdf
  local qpdf_path
  if ! qpdf_path=$(resolve_qpdf); then
    echo "ERROR: qpdf resolution failed" >> "$DEBUG_LOG" 2>&1
    fatal "qpdf not found. Please reinstall Template Print."
  fi
  echo "qpdf path resolved: ${qpdf_path}" >> "$DEBUG_LOG" 2>&1
  
  # Choose template
  echo "Choosing template..." >> "$DEBUG_LOG" 2>&1
  local template_path
  template_path="$(choose_template)"
  echo "Template chosen: ${template_path}" >> "$DEBUG_LOG" 2>&1
  
  # Choose printer
  echo "Choosing printer..." >> "$DEBUG_LOG" 2>&1
  local printer
  printer="$(choose_printer)"
  echo "Printer chosen: ${printer}" >> "$DEBUG_LOG" 2>&1
  
  # Create temporary directory for composed PDF
  local temp_dir
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "${temp_dir}"' EXIT INT TERM HUP
  echo "Temp directory: ${temp_dir}" >> "$DEBUG_LOG" 2>&1
  
  local composed_pdf="${temp_dir}/composed.pdf"
  
  # Compose PDF
  compose_with_qpdf "${qpdf_path}" "${MODE}" "${template_path}" "${input_pdf}" "${composed_pdf}"
  
  if [[ ! -f "${composed_pdf}" ]]; then
    echo "ERROR: Composed PDF not found at ${composed_pdf}" >> "$DEBUG_LOG" 2>&1
    fatal "Failed to generate composed PDF."
  fi
  
  echo "Composed PDF created: ${composed_pdf}" >> "$DEBUG_LOG" 2>&1
  echo "Composed PDF size: $(stat -f%z "${composed_pdf}" 2>/dev/null || echo "unknown") bytes" >> "$DEBUG_LOG" 2>&1
  
  # Print
  local -a lp_args=(-o media=Letter -o sides=one-sided -o fit-to-page -d "${printer}")
  echo "Printing..." >> "$DEBUG_LOG" 2>&1
  echo "  Printer: ${printer}" >> "$DEBUG_LOG" 2>&1
  echo "  lp args: ${lp_args[*]}" >> "$DEBUG_LOG" 2>&1
  echo "  PDF: ${composed_pdf}" >> "$DEBUG_LOG" 2>&1
  
  if lp "${lp_args[@]}" "${composed_pdf}" >/dev/null 2>&1; then
    echo "  Print job submitted successfully" >> "$DEBUG_LOG" 2>&1
  else
    echo "  ERROR: Print job failed (exit code: $?)" >> "$DEBUG_LOG" 2>&1
  fi
  
  # Success notification (optional)
  osascript -e "display notification \"Printed with template: $(basename "${template_path}")\" with title \"Template Print\"" >/dev/null 2>&1 || true
  
  echo "=== Main function completed ===" >> "$DEBUG_LOG" 2>&1
}

main "$@"

