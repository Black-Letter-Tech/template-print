#!/usr/bin/env bash
set -euo pipefail

WORKFLOW_NAME="TemplatePrint.workflow"
TARGET_PATH="${HOME}/Library/PDF Services/${WORKFLOW_NAME}"
DEFAULTS_DOMAIN="com.blacklettertech.template-print"
PREFS_FILE="${HOME}/Library/Preferences/${DEFAULTS_DOMAIN}.plist"

usage() {
  cat <<EOF
Usage: $(basename "$0") [-y] [--all]

Removes ${WORKFLOW_NAME} from ${HOME}/Library/PDF Services.

Options:
  -y, --yes   Skip confirmation prompt.
  -a, --all   Also remove user preferences (com.blacklettertech.template-print).
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
REMOVE_PREFS=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)
      AUTO_YES=1
      shift
      ;;
    -a|--all)
      REMOVE_PREFS=1
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
  prompt="Remove ${TARGET_PATH}?"
  if (( REMOVE_PREFS )); then
    prompt="Remove ${WORKFLOW_NAME} and preferences (${DEFAULTS_DOMAIN})?"
  fi
  if ! confirm "$prompt"; then
    log "Aborted."
    exit 0
  fi
fi

rm -rf "${TARGET_PATH}"
log "Removed ${WORKFLOW_NAME} from PDF Services."

if (( REMOVE_PREFS )); then
  defaults delete "${DEFAULTS_DOMAIN}" >/dev/null 2>&1 || true
  log "Removed preferences: ${DEFAULTS_DOMAIN}"
  if [[ -f "$PREFS_FILE" ]]; then
    rm -f "$PREFS_FILE"
    log "Removed preferences file: ${PREFS_FILE}"
  else
    log "No preferences found."
  fi
fi

