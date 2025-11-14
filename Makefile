SHELL := /bin/bash

VERSION ?= $(shell git describe --tags --abbrev=0 2>/dev/null || echo 0.1.0-dev)
DIST_DIR := dist
ARCHIVE := template-print-$(VERSION).tar.gz
PKG_SCRIPT := pkg/build_pkg.sh

.PHONY: lint pkg pkg-macos archive install-workflow uninstall-workflow install-dev uninstall-dev clean distclean

lint:
	@command -v shellcheck >/dev/null 2>&1 || { echo "shellcheck is required for linting" >&2; exit 1; }
	shellcheck files/template-print.sh scripts/install_workflow.sh scripts/uninstall_workflow.sh pkg/scripts/postinstall

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

install-dev:
	@echo "Installing development symlinks..."
	@mkdir -p /usr/local/bin
	@ln -sf "$(CURDIR)/files/template-print.sh" /usr/local/bin/template-print
	@echo "Symlinked template-print.sh to /usr/local/bin/template-print"
	@bash scripts/install_workflow.sh --symlink
	@echo "Development installation complete. Changes to source files will be immediately available."

uninstall-dev:
	@echo "Removing development symlinks..."
	@if [ -L /usr/local/bin/template-print ]; then \
		rm /usr/local/bin/template-print; \
		echo "Removed symlink: /usr/local/bin/template-print"; \
	fi
	@bash scripts/uninstall_workflow.sh -y
	@echo "Development uninstallation complete."

clean:
	rm -rf $(DIST_DIR)
	rm -rf pkg/payload

distclean: clean

