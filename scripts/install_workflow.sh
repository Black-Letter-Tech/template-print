#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

WORKFLOW_NAME="TemplatePrint.workflow"
DEST_DIR="${HOME}/Library/PDF Services"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--source PATH] [--symlink]

Copies or symlinks the ${WORKFLOW_NAME} bundle into ${DEST_DIR}.

Options:
  --source PATH   Explicit path to the workflow bundle.
  --symlink       Create a symlink instead of copying (useful for development).
  -h, --help      Show this help message.
EOF
}

log() {
  printf '[template-print] %s\n' "$*"
}

fail() {
  log "Error: $*"
  exit 1
}

resolve_workflow() {
  local override="$1"
  if [[ -n "${override}" ]]; then
    [[ -d "${override}" ]] || fail "Provided workflow path '${override}' is not a directory."
    printf '%s\n' "${override}"
    return 0
  fi

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  local -a candidates=()
  candidates+=("${TEMPLATE_PRINT_WORKFLOW_SRC:-}")
  candidates+=("${script_dir}/../workflow/${WORKFLOW_NAME}")
  candidates+=("${script_dir}/../${WORKFLOW_NAME}")
  candidates+=("${script_dir}/../../${WORKFLOW_NAME}")

  if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
    candidates+=("${HOMEBREW_PREFIX}/share/template-print/${WORKFLOW_NAME}")
    local cellar_path
    for cellar_path in "${HOMEBREW_PREFIX}/Cellar/template-print"/*/share/template-print/"${WORKFLOW_NAME}"; do
      candidates+=("${cellar_path}")
    done
  fi

  local candidate
  for candidate in "${candidates[@]}"; do
    [[ -n "${candidate}" ]] || continue
    if [[ -d "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  fail "Unable to locate ${WORKFLOW_NAME}. Pass --source PATH or set TEMPLATE_PRINT_WORKFLOW_SRC."
}

SOURCE_OVERRIDE=""
USE_SYMLINK=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)
      [[ $# -ge 2 ]] || fail "Missing path after --source."
      SOURCE_OVERRIDE="$2"
      shift 2
      ;;
    --symlink)
      USE_SYMLINK=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown option: $1"
      ;;
  esac
done

WORKFLOW_SRC="$(resolve_workflow "${SOURCE_OVERRIDE}")"

mkdir -p "${DEST_DIR}"

# Remove existing workflow (directory or symlink) if it exists
if [[ -e "${DEST_DIR}/${WORKFLOW_NAME}" ]]; then
  rm -rf "${DEST_DIR}/${WORKFLOW_NAME}"
fi

if [[ "${USE_SYMLINK}" == "true" ]]; then
  log "Creating symlink for '${WORKFLOW_NAME}' in '${DEST_DIR}'"
  ln -sf "${WORKFLOW_SRC}" "${DEST_DIR}/${WORKFLOW_NAME}"
  log "Symlink created. Changes to source workflow will be immediately available."
else
  log "Installing '${WORKFLOW_NAME}' to '${DEST_DIR}'"
  rsync -a --delete "${WORKFLOW_SRC}/" "${DEST_DIR}/${WORKFLOW_NAME}/"
fi

log "Workflow installed. It will appear under Print → PDF → Template Print after restarting the print dialog."

