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

# Detect qpdf binary location
detect_qpdf() {
    local qpdf_path
    local bundled_qpdf="$PROJECT_ROOT/pkg/qpdf-bundled/bin/qpdf"
    
    # Check for pre-bundled qpdf first (preferred)
    if [[ -x "$bundled_qpdf" ]]; then
        log "Using pre-bundled qpdf from: $bundled_qpdf"
        printf '%s\n' "$bundled_qpdf"
        return 0
    fi
    
    # Fall back to system detection (with warning)
    log "Warning: Pre-bundled qpdf not found. Falling back to system qpdf."
    log "Run 'make prepare-qpdf' to build and bundle qpdf from source."
    
    # Check common Homebrew locations
    for path in /opt/homebrew/bin/qpdf /usr/local/bin/qpdf; do
        if [[ -x "$path" ]]; then
            qpdf_path="$path"
            break
        fi
    done
    
    # Fall back to command -v
    if [[ -z "${qpdf_path:-}" ]]; then
        if qpdf_path=$(command -v qpdf 2>/dev/null); then
            [[ -n "$qpdf_path" ]] || return 1
        else
            return 1
        fi
    fi
    
    printf '%s\n' "$qpdf_path"
    return 0
}

# Copy qpdf and its dependencies
bundle_qpdf() {
    local qpdf_src="$1"
    local qpdf_dest="$2"
    local lib_dir="$3"
    local bundled_dir="$PROJECT_ROOT/pkg/qpdf-bundled"
    
    log "Bundling qpdf from: $qpdf_src"
    
    # Create destination directories
    mkdir -p "$(dirname "$qpdf_dest")"
    mkdir -p "$lib_dir"
    
    # Check if source is from pre-bundled directory (already bundled with dylibbundler)
    if [[ "$qpdf_src" == "$bundled_dir/bin/qpdf" ]] && [[ -d "$bundled_dir/lib" ]]; then
        log "Using pre-bundled qpdf (already has dependencies bundled)"
        
        # Just copy the binary
        cp "$qpdf_src" "$qpdf_dest"
        chmod 755 "$qpdf_dest"
        
        # Copy all libraries (already properly bundled)
        if [[ -d "$bundled_dir/lib" ]] && [[ -n "$(ls -A "$bundled_dir/lib" 2>/dev/null)" ]]; then
            log "  Copying bundled libraries..."
            cp -R "$bundled_dir/lib/"* "$lib_dir/" 2>/dev/null || true
            chmod -R 755 "$lib_dir"
        fi
        
        log "qpdf bundled to: $qpdf_dest"
        return 0
    fi
    
    # Fallback: manual dependency bundling (for system qpdf)
    log "Bundling qpdf dependencies manually (fallback mode)"
    
    # Copy qpdf binary
    cp "$qpdf_src" "$qpdf_dest"
    chmod 755 "$qpdf_dest"
    
    # Find and copy dependencies using otool
    if command -v otool >/dev/null 2>&1; then
        local deps
        deps=$(otool -L "$qpdf_src" 2>/dev/null | grep -E '\t/.*\.dylib' | awk '{print $1}' | sed 's|^[[:space:]]*||' || true)
        
        for dep in $deps; do
            # Skip system libraries (they're in standard locations)
            if [[ "$dep" == /usr/lib/* ]] || [[ "$dep" == /System/Library/* ]]; then
                continue
            fi
            
            # Skip if it's already a relative path or @rpath
            if [[ "$dep" == @* ]] || [[ "$dep" != /* ]]; then
                continue
            fi
            
            # Copy the library if it exists
            if [[ -f "$dep" ]]; then
                local lib_name=$(basename "$dep")
                local lib_dest="$lib_dir/$lib_name"
                
                log "  Copying dependency: $lib_name"
                cp "$dep" "$lib_dest"
                chmod 755 "$lib_dest"
                
                # Update the library's install name in qpdf binary
                if command -v install_name_tool >/dev/null 2>&1; then
                    install_name_tool -change "$dep" "@loader_path/../lib/$lib_name" "$qpdf_dest" 2>/dev/null || true
                fi
            fi
        done
        
        # Set library search path in qpdf binary
        if command -v install_name_tool >/dev/null 2>&1 && [[ -n "$deps" ]]; then
            install_name_tool -add_rpath "@loader_path/../lib" "$qpdf_dest" 2>/dev/null || true
        fi
    fi
    
    log "qpdf bundled to: $qpdf_dest"
}

# Clean and prepare directories
log "Preparing build directories..."
rm -rf "$PAYLOAD_DIR"
mkdir -p "$PAYLOAD_DIR/usr/local/bin"
mkdir -p "$PAYLOAD_DIR/Library/PDF Services"
mkdir -p "$PAYLOAD_DIR/Library/Application Support/template-print/bin"
mkdir -p "$PAYLOAD_DIR/Library/Application Support/template-print/lib"
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

# Bundle qpdf
log "Bundling qpdf..."
if qpdf_src=$(detect_qpdf); then
    QPDF_DEST="$PAYLOAD_DIR/Library/Application Support/template-print/bin/qpdf"
    QPDF_LIB_DIR="$PAYLOAD_DIR/Library/Application Support/template-print/lib"
    bundle_qpdf "$qpdf_src" "$QPDF_DEST" "$QPDF_LIB_DIR"
else
    log "ERROR: qpdf not found. Install it with: brew install qpdf"
    log "qpdf is required to build the installer package."
    exit 1
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
