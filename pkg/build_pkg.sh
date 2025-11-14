#!/bin/bash
set -euo pipefail

VERSION="${1:-$(git describe --tags --abbrev=0 2>/dev/null || echo '0.1.0')}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/pkg"
PAYLOAD_DIR="$BUILD_DIR/payload"
DIST_DIR="$PROJECT_ROOT/dist"
PKG_ID="com.blacklettertech.template-print"
PKG_NAME="template-print"
OUTPUT_PKG="$DIST_DIR/${PKG_NAME}-${VERSION}.pkg"

log() {
    echo "[build] $*" >&2
}

# Clean and prepare directories
log "Preparing build directories..."
rm -rf "$PAYLOAD_DIR"
mkdir -p "$PAYLOAD_DIR/usr/local/bin"
mkdir -p "$PAYLOAD_DIR/Library/PDF Services"
mkdir -p "$PAYLOAD_DIR/Library/Application Support/template-print"
mkdir -p "$PAYLOAD_DIR/Applications/Utilities"
mkdir -p "$DIST_DIR"

# Stage files
log "Staging files..."
cp "$PROJECT_ROOT/files/template-print.sh" "$PAYLOAD_DIR/usr/local/bin/template-print"
chmod 755 "$PAYLOAD_DIR/usr/local/bin/template-print"

cp -R "$PROJECT_ROOT/workflow/TemplatePrint.workflow" "$PAYLOAD_DIR/Library/PDF Services/"

# Stage examples in Application Support (will be moved to /Users/Shared/PDFTemplates/examples in postinstall)
if [[ -d "$PROJECT_ROOT/examples" ]]; then
    cp -R "$PROJECT_ROOT/examples" "$PAYLOAD_DIR/Library/Application Support/template-print/"
fi

cp -R "$PROJECT_ROOT/pkg/uninstaller/Template Print Uninstaller.app" "$PAYLOAD_DIR/Applications/Utilities/"

# Build the package
log "Building package..."
pkgbuild \
    --root "$PAYLOAD_DIR" \
    --scripts "$BUILD_DIR/scripts" \
    --identifier "$PKG_ID" \
    --version "$VERSION" \
    --install-location "/" \
    "$OUTPUT_PKG"

log "Package built: $OUTPUT_PKG"
log "Package size: $(du -h "$OUTPUT_PKG" | cut -f1)"
log ""
log "To install: sudo installer -pkg '$OUTPUT_PKG' -target /"
log "Or double-click the .pkg file and follow the installer"
