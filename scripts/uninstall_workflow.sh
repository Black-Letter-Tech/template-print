#!/usr/bin/env bash
set -euo pipefail

WORKFLOW_NAME="TemplatePrint.workflow"
TARGET_PATH="${HOME}/Library/PDF Services/${WORKFLOW_NAME}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [-y]

Removes ${WORKFLOW_NAME} from ${HOME}/Library/PDF Services.

Options:
  -y, --yes   Skip confirmation prompt.
  -h, --help  Show this help message.
EOF
}

log() {
  printf '[template-print] %s\n' "$*"
}

confirm() {
  local prompt="$1"
  local reply
  read -r -p "${prompt} [y/N] " reply
  [[ "${reply}" =~ ^[Yy]$ ]]
}

AUTO_YES=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)
      AUTO_YES=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ ! -e "${TARGET_PATH}" ]]; then
  log "No workflow found at ${TARGET_PATH}"
  exit 0
fi

if (( AUTO_YES == 0 )); then
  if ! confirm "Remove ${TARGET_PATH}?"; then
    log "Aborted."
    exit 0
  fi
fi

rm -rf "${TARGET_PATH}"
log "Removed ${WORKFLOW_NAME} from PDF Services."

