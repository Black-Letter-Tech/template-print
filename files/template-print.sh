# shellcheck disable=SC2154
#!/usr/bin/env zsh
set -euo pipefail

VERSION="0.1.0-dev"
DEFAULT_TEMPLATE_DIR="/Users/Shared/PDFTemplates"
DEFAULTS_DOMAIN="com.blacklettertech.template-print"
DEFAULTS_KEY="lastTemplatePath"
SCRIPT_NAME="template-print"

usage() {
  cat <<EOF
${SCRIPT_NAME} ${VERSION}

Usage:
  ${SCRIPT_NAME} [options] <pdf>

Options:
  -t, --template PATH        Path to template PDF to apply.
  -d, --dir DIR              Directory containing template PDFs (default: ${DEFAULT_TEMPLATE_DIR}).
  -m, --mode MODE            underlay (default) or overlay.
  -p, --printer NAME         Target printer (default: system default).
  -c, --choose               Present template chooser dialog.
  -r, --remember 0|1         Persist last chosen template (default: 1).
  -l, --list                 List available templates and exit.
  -h, --help                 Show this help.
      --version              Print version and exit.
EOF
}

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
    /usr/bin/osascript -e "display dialog \"$(escape_osascript "$message")\" with title \"${SCRIPT_NAME}\" buttons {\"OK\"} default button \"OK\" with icon caution" >/dev/null 2>&1 || true
  fi
}

fatal() {
  local message="$1"
  printf '%s: %s\n' "${SCRIPT_NAME}" "${message}" >&2
  alert "${message}"
  exit "${2:-1}"
}

info() {
  printf '%s\n' "$1"
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
  if qpdf=$(detect_program /opt/homebrew/bin/qpdf /usr/local/bin/qpdf qpdf); then
    printf '%s\n' "${qpdf}"
    return 0
  fi
  return 1
}

list_templates() {
  local dir="$1"
  [[ -d "${dir}" ]] || fatal "Template directory '${dir}' does not exist."

  local -a templates=()
  discover_templates "${dir}" templates

  (( ${#templates} > 0 )) || fatal "No templates found in '${dir}'."

  local template
  for template in "${templates[@]}"; do
    printf '%s\n' "${template}"
  done
}

load_default_printer() {
  local printer
  if printer=$(lpstat -d 2>/dev/null | awk -F': ' 'NR==1 {print $2}'); then
    printf '%s' "${printer}"
    return 0
  fi
  return 1
}

remember_template() {
  local path="$1"
  defaults write "${DEFAULTS_DOMAIN}" "${DEFAULTS_KEY}" -string "${path}" >/dev/null 2>&1 || true
}

forget_template() {
  defaults delete "${DEFAULTS_DOMAIN}" "${DEFAULTS_KEY}" >/dev/null 2>&1 || true
}

load_last_template() {
  defaults read "${DEFAULTS_DOMAIN}" "${DEFAULTS_KEY}" 2>/dev/null || true
}

choose_template() {
  local -n _templates=$1
  local defaults_mode="$2"
  local last_template
  last_template="$(load_last_template)"

  local -a display_names=()
  local -A lookup=()
  local item
  for item in "${_templates[@]}"; do
    local name="${item##*/}"
    display_names+=("${name}")
    lookup["${name}"]="${item}"
  done

  local default_clause=""
  if [[ -n "${last_template}" ]]; then
    local last_name="${last_template##*/}"
    if [[ -n "${lookup[${last_name}]-}" ]]; then
      default_clause="default items {\"${last_name}\"}"
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

  [[ -n "${quoted_list}" ]] || fatal "No templates available to choose."

  local selection
  selection=$(/usr/bin/osascript <<EOF
set _templates to {${quoted_list}}
set _result to choose from list _templates with prompt "Select a template to apply" ${default_clause} OK button name "Use Template" cancel button name "Cancel"
if _result is false then
  error number -128
end if
item 1 of _result
EOF
  ) || fatal "Template selection cancelled." 1

  local chosen="${lookup[${selection}]}"
  [[ -n "${chosen}" ]] || fatal "Unable to resolve chosen template."

  if [[ "${defaults_mode}" == "1" ]]; then
    remember_template "${chosen}"
  else
    forget_template
  fi

  printf '%s\n' "${chosen}"
}

compose_with_qpdf() {
  local compositor="$1"
  local mode="$2"
  local template="$3"
  local input_pdf="$4"
  local output_pdf="$5"

  local flag="--underlay"
  [[ "${mode}" == "overlay" ]] && flag="--overlay"

  "${compositor}" "${flag}" "${template}" -- "${input_pdf}" "${output_pdf}"
}

discover_templates() {
  local dir="$1"
  local -n _out=$2
  _out=()
  while IFS= read -r line; do
    [[ -n "${line}" ]] || continue
    _out+=("${line}")
  done < <(find "${dir}" -maxdepth 1 -type f \( -iname '*.pdf' -o -iname '*.PDF' \) -print0 | tr '\0' '\n' | sed '/^$/d' | sort)
}

main() {
  local template_path=""
  local templates_dir="${TEMPLATE_PRINT_DIR:-$DEFAULT_TEMPLATE_DIR}"
  local mode="underlay"
  local printer=""
  local choose_template_flag=0
  local remember_last=1
  local list_only=0

  local args=("$@")
  local positional=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -t|--template)
        [[ $# -ge 2 ]] || fatal "Missing value for $1."
        template_path="$2"
        shift 2
        ;;
      -d|--dir)
        [[ $# -ge 2 ]] || fatal "Missing value for $1."
        templates_dir="$2"
        shift 2
        ;;
      -m|--mode)
        [[ $# -ge 2 ]] || fatal "Missing value for $1."
        mode="$2"
        shift 2
        ;;
      -p|--printer)
        [[ $# -ge 2 ]] || fatal "Missing value for $1."
        printer="$2"
        shift 2
        ;;
      -c|--choose)
        choose_template_flag=1
        shift
        ;;
      -r|--remember)
        [[ $# -ge 2 ]] || fatal "Missing value for $1."
        remember_last="$2"
        shift 2
        ;;
      -l|--list)
        list_only=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --version)
        printf '%s\n' "${VERSION}"
        exit 0
        ;;
      --)
        shift
        while [[ $# -gt 0 ]]; do
          positional+=("$1")
          shift
        done
        ;;
      -*)
        fatal "Unknown option: $1"
        ;;
      *)
        positional+=("$1")
        shift
        ;;
    esac
  done

  if [[ "${mode}" != "underlay" && "${mode}" != "overlay" ]]; then
    fatal "Invalid mode '${mode}'. Use underlay or overlay."
  fi

  if [[ "${remember_last}" != "0" && "${remember_last}" != "1" ]]; then
    fatal "--remember expects 0 or 1."
  fi

  if (( list_only )); then
    list_templates "${templates_dir}"
    exit 0
  fi

  if (( ${#positional[@]} == 0 )); then
    fatal "Missing input PDF. Provide a file to print."
  fi

  local input_pdf="${positional[1]}"
  [[ -f "${input_pdf}" ]] || fatal "Input PDF '${input_pdf}' does not exist."

  [[ -d "${templates_dir}" ]] || fatal "Template directory '${templates_dir}' does not exist."

  local qpdf_path
  if ! qpdf_path=$(resolve_qpdf); then
    fatal "qpdf not found. Install it (e.g. via Homebrew: brew install qpdf)."
  fi

  local -a templates=()
  discover_templates "${templates_dir}" templates

  if (( choose_template_flag )); then
    (( ${#templates} > 0 )) || fatal "No templates found in '${templates_dir}'."
    template_path="$(choose_template templates "${remember_last}")"
  fi

  if [[ -z "${template_path}" ]]; then
    if (( ${#templates} == 1 )); then
      template_path="${templates[1]}"
    elif (( ${#templates} == 0 )); then
      fatal "No templates found in '${templates_dir}'."
    else
      fatal "Multiple templates found. Specify one with --template or --choose."
    fi
  fi

  [[ -f "${template_path}" ]] || fatal "Template '${template_path}' does not exist."

  if (( remember_last )) && (( ! choose_template_flag )); then
    remember_template "${template_path}"
  fi

  if [[ -z "${printer}" ]]; then
    if printer=$(load_default_printer); then
      :
    else
      fatal "Unable to determine default printer. Specify one with --printer."
    fi
  fi

  local temp_dir
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "${temp_dir}"' EXIT INT TERM HUP

  local composed_pdf="${temp_dir}/composed.pdf"

  compose_with_qpdf "${qpdf_path}" "${mode}" "${template_path}" "${input_pdf}" "${composed_pdf}"

  if [[ ! -f "${composed_pdf}" ]]; then
    fatal "Failed to generate composed PDF."
  fi

  local -a lp_args=(-o media=Letter -o sides=one-sided -o fit-to-page -d "${printer}")
  lp "${lp_args[@]}" "${composed_pdf}" >/dev/null

  info "Sent '${input_pdf}' to printer '${printer}' with template '${template_path}' (${mode})."
}

main "$@"

