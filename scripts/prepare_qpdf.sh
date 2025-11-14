#!/usr/bin/env bash
set -euo pipefail

# Script to download, build, and bundle qpdf from source
# This creates a self-contained qpdf with all dependencies bundled

QPDF_VERSION="${QPDF_VERSION:-latest}"
QPDF_REPO="https://github.com/qpdf/qpdf.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/pkg/qpdf-build"
BUNDLED_DIR="$PROJECT_ROOT/pkg/qpdf-bundled"
TEMP_INSTALL_DIR="$BUILD_DIR/install"

log() {
    echo "[prepare-qpdf] $*" >&2
}

error() {
    log "ERROR: $*"
    exit 1
}

# Check for required tools
check_requirements() {
    local missing=()
    
    if ! command -v cmake >/dev/null 2>&1; then
        missing+=("cmake")
    fi
    
    if ! command -v make >/dev/null 2>&1; then
        missing+=("make")
    fi
    
    if ! command -v git >/dev/null 2>&1; then
        missing+=("git")
    fi
    
    if ! command -v dylibbundler >/dev/null 2>&1; then
        missing+=("dylibbundler (install via: brew install dylibbundler)")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required tools: ${missing[*]}"
    fi
}

# Detect architecture
detect_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        arm64)
            echo "arm64"
            ;;
        x86_64)
            echo "x86_64"
            ;;
        *)
            error "Unsupported architecture: $arch"
            ;;
    esac
}

# Clone or update qpdf source
get_qpdf_source() {
    local source_dir="$BUILD_DIR/source"
    
    if [[ -d "$source_dir" ]]; then
        log "Updating existing qpdf source..."
        (cd "$source_dir" && git fetch --tags)
    else
        log "Cloning qpdf source from GitHub..."
        git clone "$QPDF_REPO" "$source_dir"
    fi
    
    cd "$source_dir"
    
    # Checkout specified version
    if [[ "$QPDF_VERSION" == "latest" ]]; then
        log "Checking out latest release..."
        local latest_tag
        latest_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "master")
        log "Latest tag: $latest_tag"
        git checkout "$latest_tag" 2>/dev/null || git checkout master
        QPDF_VERSION="$latest_tag"
    else
        log "Checking out version: $QPDF_VERSION"
        git checkout "$QPDF_VERSION" 2>/dev/null || error "Version $QPDF_VERSION not found"
    fi
    
    echo "$source_dir"
}

# Build qpdf from source
build_qpdf() {
    local source_dir="$1"
    local build_dir="$BUILD_DIR/build"
    local install_dir="$TEMP_INSTALL_DIR"
    
    log "Building qpdf..."
    
    # Create build directory
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Configure with cmake
    log "Configuring qpdf build..."
    cmake "$source_dir" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$install_dir" \
        -DCMAKE_OSX_ARCHITECTURES="$(detect_arch)" \
        -DBUILD_SHARED_LIBS=OFF \
        -DREQUIRE_CRYPTO_NATIVE=ON
    
    # Build
    log "Compiling qpdf (this may take a few minutes)..."
    make -j$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
    
    # Install to temporary location
    log "Installing qpdf to temporary location..."
    make install
    
    echo "$install_dir"
}

# Bundle qpdf and dependencies using dylibbundler
bundle_qpdf() {
    local install_dir="$1"
    local qpdf_binary="$install_dir/bin/qpdf"
    
    if [[ ! -f "$qpdf_binary" ]]; then
        error "qpdf binary not found at $qpdf_binary"
    fi
    
    log "Bundling qpdf and dependencies with dylibbundler..."
    
    # Create bundled directory structure
    mkdir -p "$BUNDLED_DIR/bin"
    mkdir -p "$BUNDLED_DIR/lib"
    
    # Copy qpdf binary
    cp "$qpdf_binary" "$BUNDLED_DIR/bin/qpdf"
    chmod 755 "$BUNDLED_DIR/bin/qpdf"
    
    # Use dylibbundler to bundle all dependencies
    cd "$BUNDLED_DIR"
    dylibbundler \
        -od -b \
        -x "bin/qpdf" \
        -d "lib" \
        -p "@loader_path/../lib" \
        -of
    
    log "qpdf bundled successfully"
    
    # Store version info
    echo "$QPDF_VERSION" > "$BUNDLED_DIR/VERSION"
    echo "$(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "$BUNDLED_DIR/VERSION"
    echo "$(detect_arch)" >> "$BUNDLED_DIR/VERSION"
    
    log "Bundled qpdf version: $QPDF_VERSION"
    log "Architecture: $(detect_arch)"
    log "Location: $BUNDLED_DIR"
}

# Clean up build directory
cleanup() {
    if [[ -d "$BUILD_DIR" ]]; then
        log "Cleaning up build directory..."
        rm -rf "$BUILD_DIR"
    fi
}

# Main execution
main() {
    log "Preparing qpdf from source..."
    log "Version: $QPDF_VERSION"
    
    check_requirements
    
    # Clean up any previous build
    if [[ -d "$BUILD_DIR" ]]; then
        log "Removing previous build directory..."
        rm -rf "$BUILD_DIR"
    fi
    
    # Create build directory
    mkdir -p "$BUILD_DIR"
    
    # Get source
    source_dir=$(get_qpdf_source)
    
    # Build
    install_dir=$(build_qpdf "$source_dir")
    
    # Bundle
    bundle_qpdf "$install_dir"
    
    # Cleanup
    cleanup
    
    log "qpdf preparation complete!"
    log "Bundled qpdf is ready at: $BUNDLED_DIR"
}

# Run main function
main "$@"

