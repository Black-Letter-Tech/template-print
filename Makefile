SHELL := /bin/bash

VERSION ?= $(shell git describe --tags --abbrev=0 2>/dev/null || echo 0.1.0-dev)
DIST_DIR := dist
ARCHIVE := template-print-$(VERSION).tar.gz
PKG_SCRIPT := pkg/build_pkg.sh

.PHONY: lint pkg pkg-macos archive install-workflow uninstall-workflow prepare-qpdf clean-qpdf test test-unit test-integration clean distclean

lint:
	@command -v shellcheck >/dev/null 2>&1 || { echo "shellcheck is required for linting" >&2; exit 1; }
	shellcheck workflow/TemplatePrint.workflow/Contents/Scripts/template-print.sh scripts/install_workflow.sh scripts/uninstall_workflow.sh scripts/prepare_qpdf.sh pkg/scripts/postinstall pkg/build_pkg.sh

pkg: pkg-macos

pkg-macos:
	@command -v pkgbuild >/dev/null 2>&1 || { echo "pkgbuild is required (comes with Xcode Command Line Tools)" >&2; exit 1; }
	@echo "Building macOS .pkg installer for template-print $(VERSION)"
	@bash $(PKG_SCRIPT) $(VERSION)

archive: clean
	@echo "Packaging template-print $(VERSION) as tarball"
	mkdir -p $(DIST_DIR)/template-print-$(VERSION)
	rsync -a --delete \
		--exclude '.git' \
		--exclude '.gitignore' \
		--exclude '$(DIST_DIR)' \
		--exclude '*.tar.gz' \
		--exclude '*.pkg' \
		./ $(DIST_DIR)/template-print-$(VERSION)/
	tar -czf $(DIST_DIR)/$(ARCHIVE) -C $(DIST_DIR) template-print-$(VERSION)
	@echo "Created $(DIST_DIR)/$(ARCHIVE)"

install-workflow:
	bash scripts/install_workflow.sh

uninstall-workflow:
	bash scripts/uninstall_workflow.sh -y

prepare-qpdf:
	@echo "Preparing qpdf from source (this may take several minutes)..."
	@bash scripts/prepare_qpdf.sh
	@echo "qpdf preparation complete. Run 'make pkg' to build the installer."

clean-qpdf:
	@echo "Cleaning bundled qpdf..."
	@rm -rf pkg/qpdf-bundled
	@rm -rf pkg/qpdf-build
	@echo "Bundled qpdf removed."

test: test-unit test-integration

test-unit:
	@command -v bats >/dev/null 2>&1 || { echo "bats is required for testing. Install with: brew install bats-core" >&2; exit 1; }
	@echo "Running unit tests..."
	@bats tests/unit/

test-integration:
	@command -v bats >/dev/null 2>&1 || { echo "bats is required for testing. Install with: brew install bats-core" >&2; exit 1; }
	@echo "Running integration tests..."
	@bats tests/integration/

clean:
	rm -rf $(DIST_DIR)
	rm -rf pkg/payload

distclean: clean

