# Debian Packaging Structure

## Overview

This project supports **two** Debian packaging approaches:

1. **Binary Package** (`DEBIAN/`) - Quick, simple binary package
2. **Source Package** (`debian/`) - Proper Debian source package

## Binary Package (DEBIAN/)

**Location**: `DEBIAN/` (uppercase)

**Purpose**: Quick binary package creation without full Debian toolchain

**Files**:
- `DEBIAN/control` - Binary package metadata
- `DEBIAN/postinst` - Post-installation script
- `DEBIAN/postrm` - Post-removal script

**Build**:
```bash
make package
# Creates: build/rmd_1.0.0_all.deb
```

**Install**:
```bash
sudo dpkg -i build/rmd_1.0.0_all.deb
```

**Use Case**: Personal use, quick distribution, simple deployments

## Source Package (debian/)

**Location**: `debian/` (lowercase)

**Purpose**: Proper Debian source package following Debian Policy

**Files**:
- `debian/control` - Source and binary package definitions
- `debian/rules` - Build instructions (Makefile using debhelper)
- `debian/changelog` - Version history
- `debian/copyright` - License information
- `debian/postinst` - Post-installation script
- `debian/postrm` - Post-removal script
- `debian/source/format` - Source format (3.0 quilt)

**Build**:
```bash
make source-package
# Requires: debhelper, build-essential
# Creates in parent directory:
#   - rmd_1.0.0-1.dsc
#   - rmd_1.0.0.orig.tar.xz
#   - rmd_1.0.0-1.debian.tar.xz
#   - rmd_1.0.0-1_all.deb
```

**Install**:
```bash
sudo dpkg -i ../rmd_1.0.0-1_all.deb
```

**Use Case**: 
- Uploading to Debian/Ubuntu repositories
- Allowing others to rebuild from source
- Following Debian packaging standards
- Creating proper source packages

## Key Differences

| Feature | DEBIAN/ (Binary) | debian/ (Source) |
|---------|------------------|------------------|
| Complexity | Simple | More complex |
| Build Tool | `dpkg-deb` | `debuild`/`dpkg-buildpackage` |
| Dependencies | None | debhelper, build-essential |
| Source Package | No | Yes (.dsc, .tar.xz) |
| Repository Ready | No | Yes |
| Rebuildable | No | Yes |

## Installation Scripts Compatibility

### install.sh / uninstall.sh

These are **standalone** installation scripts, **not** part of Debian packaging:

- `install.sh` - Manual installation script
- `uninstall.sh` - Manual uninstallation script

They work independently of Debian packages and can be used for:
- Quick manual installation
- Systems without package management
- Testing before packaging

**Note**: When using Debian packages, the package manager handles installation/removal automatically via `postinst`/`postrm` scripts.

## Recommendations

1. **For personal use**: Use `make package` (binary package)
2. **For distribution**: Use `make source-package` (source package)
3. **For manual installs**: Use `./install.sh` and `./uninstall.sh`

## Building Source Packages

### Prerequisites

```bash
sudo apt-get install devscripts build-essential debhelper
```

### Build Process

The `debian/rules` file uses debhelper and automatically:
1. Installs files to `debian/rmd/` directory
2. Creates proper file permissions
3. Handles man page installation
4. Runs postinst/postrm scripts

### File Installation

Files are installed via `debian/rules` in `override_dh_auto_install`:
- `rmd.sh` → `/usr/local/bin/rmd`
- `rmd.1` → `/usr/local/share/man/man1/rmd.1`
- `rmd.bash-completion` → `/usr/local/share/rmd/rmd.bash-completion`

Bash completion is symlinked to `/etc/bash_completion.d/` via `postinst`.
