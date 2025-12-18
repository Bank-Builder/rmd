# Makefile for rmd Debian package
# Copyright (c) 2025 Andrew Turpin

PACKAGE_NAME := rmd
VERSION := 1.0.0
DEB_PACKAGE := $(PACKAGE_NAME)_$(VERSION)_all.deb
BUILD_DIR := build
DEB_DIR := $(BUILD_DIR)/$(PACKAGE_NAME)

.PHONY: all clean build install uninstall test package deb source-package

all: package

# Create build directory structure
$(DEB_DIR):
	mkdir -p $(DEB_DIR)/DEBIAN
	mkdir -p $(DEB_DIR)/usr/local/bin
	mkdir -p $(DEB_DIR)/usr/local/share/man/man1
	mkdir -p $(DEB_DIR)/usr/local/share/rmd

# Copy files to build directory
$(DEB_DIR)/DEBIAN/control: DEBIAN/control | $(DEB_DIR)
	cp DEBIAN/control $(DEB_DIR)/DEBIAN/
	cp DEBIAN/postinst $(DEB_DIR)/DEBIAN/
	chmod +x $(DEB_DIR)/DEBIAN/postinst
	cp DEBIAN/postrm $(DEB_DIR)/DEBIAN/
	chmod +x $(DEB_DIR)/DEBIAN/postrm

$(DEB_DIR)/usr/local/bin/rmd: rmd.sh | $(DEB_DIR)
	cp rmd.sh $(DEB_DIR)/usr/local/bin/rmd
	chmod +x $(DEB_DIR)/usr/local/bin/rmd

$(DEB_DIR)/usr/local/share/man/man1/rmd.1: usr/local/share/man/man1/rmd.1 | $(DEB_DIR)
	cp usr/local/share/man/man1/rmd.1 $(DEB_DIR)/usr/local/share/man/man1/

$(DEB_DIR)/usr/local/share/rmd/rmd.bash-completion: rmd.bash-completion | $(DEB_DIR)
	cp rmd.bash-completion $(DEB_DIR)/usr/local/share/rmd/

# Build the package
build: $(DEB_DIR)/DEBIAN/control $(DEB_DIR)/usr/local/bin/rmd \
       $(DEB_DIR)/usr/local/share/man/man1/rmd.1 \
       $(DEB_DIR)/usr/local/share/rmd/rmd.bash-completion
	@echo "Package structure prepared in $(DEB_DIR)"

# Build Debian package
package: build
	dpkg-deb --build $(DEB_DIR) $(BUILD_DIR)/$(DEB_PACKAGE)
	@echo "Package built: $(BUILD_DIR)/$(DEB_PACKAGE)"

# Alias for package
deb: package

# Install package (requires sudo)
install: package
	sudo dpkg -i $(BUILD_DIR)/$(DEB_PACKAGE)

# Uninstall package (requires sudo)
uninstall:
	sudo dpkg -r $(PACKAGE_NAME) || true

# Run tests
test:
	./test_rmd.sh

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)
	@echo "Cleaned build directory"

# Build Debian source package (requires debhelper)
source-package:
	@if ! command -v debuild >/dev/null 2>&1 && ! command -v dpkg-buildpackage >/dev/null 2>&1; then \
		echo "Error: debuild or dpkg-buildpackage required for source package" >&2; \
		echo "Install with: sudo apt-get install devscripts build-essential" >&2; \
		exit 1; \
	fi
	@echo "Building Debian source package..."
	@if command -v debuild >/dev/null 2>&1; then \
		debuild -us -uc; \
	else \
		dpkg-buildpackage -us -uc; \
	fi
	@echo "Source package built in parent directory"

# Show help
help:
	@echo "Available targets:"
	@echo "  make              - Build the binary Debian package (default)"
	@echo "  make build        - Prepare package structure"
	@echo "  make package      - Build the .deb binary package (DEBIAN/)"
	@echo "  make deb          - Alias for package"
	@echo "  make source-package - Build proper Debian source package (debian/)"
	@echo "  make install      - Install the package (requires sudo)"
	@echo "  make uninstall    - Uninstall the package (requires sudo)"
	@echo "  make test         - Run test suite"
	@echo "  make clean        - Remove build artifacts"
	@echo "  make help         - Show this help message"
	@echo ""
	@echo "Note:"
	@echo "  - 'make package' uses DEBIAN/ for quick binary package"
	@echo "  - 'make source-package' uses debian/ for proper source package"
