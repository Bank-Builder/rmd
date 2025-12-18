# rmd - Safe rm Wrapper with Trash Integration

Copyright (c) 2025 Andrew Turpin

A lightweight bash script that wraps the `rm` command with safety features to prevent accidental data loss.

## Features

- **System File Protection**: Prevents deletion of files in protected system directories
- **Folder Detection**: Warns when attempting to delete directories
- **Config File Warnings**: Alerts when deleting hidden or configuration files
- **Trash Integration**: Moves files to GNOME trash instead of permanent deletion
- **Interactive Prompts**: Y/n/D options (trash/cancel/permanent delete)

## Installation

### Manual Installation

```bash
# Make script executable
chmod +x rmd.sh

# Install to /usr/local/bin
sudo cp rmd.sh /usr/local/bin/rmd

# Optional: Create alias in your shell config
echo "alias rm='rmd'" >> ~/.bashrc  # or ~/.zshrc
source ~/.bashrc
```

### Debian Package Installation

#### Quick Binary Package (DEBIAN/)

```bash
# Build binary package using Makefile
make package

# Install the package
sudo dpkg -i build/rmd_1.0.0_all.deb

# Or use make install
make install
```

#### Proper Source Package (debian/)

```bash
# Build source package (requires debhelper)
make source-package

# This creates in parent directory:
# - rmd_1.0.0-1.dsc (source description)
# - rmd_1.0.0.orig.tar.xz (source tarball)
# - rmd_1.0.0-1.debian.tar.xz (debian changes)
# - rmd_1.0.0-1_all.deb (binary package)

# Install the binary package
sudo dpkg -i ../rmd_1.0.0-1_all.deb
```

## Usage

```bash
# Delete a file (moves to trash)
rmd file.txt

# Delete a directory recursively
rmd -r directory/

# Skip prompts (still uses trash)
rmd -f config.txt

# Verbose mode
rmd -v file.txt

# Multiple files
rmd file1.txt file2.txt file3.txt
```

## Prompts

When deleting files, you'll be prompted with:

- **Y** (or Enter): Move file to trash (default)
- **n**: Cancel the operation
- **D**: Permanently delete (bypass trash)

## Options

- `-f, --force`: Skip safety prompts (still uses trash)
- `-r, -R, --recursive`: Remove directories recursively
- `-v, --verbose`: Explain what is being done
- `-h, --help`: Display help information

## Safety Features

### Protected System Directories

The following directories are protected from deletion:
- `/bin`, `/usr`, `/etc`, `/root`, `/sbin`
- `/lib`, `/lib64`, `/opt`, `/var`
- `/sys`, `/proc`, `/dev`, `/boot`

### Trash Location

Files are moved to: `~/.local/share/Trash/files/`

This follows the XDG Trash specification and integrates with GNOME's trash system.

## Exit Codes

- `0`: Success
- `1`: User cancelled or file not found
- `2`: System file protection triggered
- `3`: Failed to create trash directories

## Bash Completion

To enable bash completion:

```bash
# Copy completion file
sudo cp rmd.bash-completion /etc/bash_completion.d/rmd

# Or source it in your shell
source rmd.bash-completion
```

## Examples

```bash
# Safe deletion with prompt
rmd important.txt
# Delete important.txt? (Y/n/D): Y

# Delete directory
rmd -r old_project/
# This is a folder. Are you sure you want to delete it? (Y/n/D): Y

# Delete config file (with warning)
rmd .bashrc
# Warning: This appears to be a hidden/config file. Continue? (Y/n/D): Y

# Force delete (skip prompts)
rmd -f temp.txt

# Try to delete system file (blocked)
rmd /bin/ls
# rmd: cannot remove '/bin/ls': System file protection enabled
```

## Notes

- This is a safety wrapper. For permanent deletion without prompts, use `rm` directly
- Files moved to trash can be recovered from GNOME's trash
- The script respects XDG_DATA_HOME environment variable for trash location

## Feature Comparison with rm

This section tracks the functionality gap between `rmd` (safety wrapper) and the standard `rm` command.

### Status Legend
- ✓ Implemented
- ✗ Not Implemented
- ⚠ Partially Implemented

### Feature Comparison Table

| Feature | rm | rmd | Notes |
|---------|----|-----|-------|
| Basic file deletion | ✓ | ✓ | rmd moves to trash instead |
| Directory deletion (-r) | ✓ | ✓ | Requires -r flag, same as rm |
| Force mode (-f) | ✓ | ⚠ | -f skips prompts but still uses trash |
| Interactive mode (-i) | ✓ | ✗ | Not implemented (always prompts) |
| Verbose mode (-v) | ✓ | ✓ | Implemented |
| One file system (-x) | ✓ | ✗ | Not implemented |
| Preserve root (-/) | ✓ | ✗ | Not implemented |
| No dereference (-P) | ✓ | ✗ | Not implemented |
| Prompt once (-I) | ✓ | ✗ | Not implemented |
| Preserve attributes | ✓ | ⚠ | Trash preserves most attributes |
| Multiple files | ✓ | ✓ | Fully supported |
| Wildcards/globs | ✓ | ✓ | Handled by shell |
| Stdin deletion | ✓ | ✗ | Not implemented |
| Preserve SELinux context | ✓ | ✗ | Not implemented |
| System file protection | ✗ | ✓ | rmd-specific feature |
| Trash integration | ✗ | ✓ | rmd-specific feature |
| Config file warnings | ✗ | ✓ | rmd-specific feature |

### Flags Not Implemented

- `-i, --interactive`: Always prompt before removal (rmd always prompts)
- `-I`: Prompt once before removing more than three files
- `-x, --one-file-system`: Don't cross filesystem boundaries
- `-P, --no-preserve-root`: Don't treat '/' specially
- `-d, --dir`: Remove empty directories
- `--preserve-root`: Don't remove '/' (always enabled in rmd)
- `--no-preserve-root`: Allow removal of '/' (never allowed in rmd)

### Behavioral Differences

1. **Default behavior**: `rmd` moves to trash, `rm` permanently deletes
2. **System protection**: `rmd` blocks system file deletion, `rm` does not
3. **Prompts**: `rmd` always prompts (unless -f), `rm` only prompts with -i
4. **Force flag**: `rm -f` permanently deletes, `rmd -f` still uses trash (use 'D' in prompt for permanent delete)

### Compatibility Notes

- Most common `rm` usage patterns are supported
- Scripts using `rm -f` will work but files go to trash instead of being permanently deleted
- For true permanent deletion, users must respond 'D' to prompts or use `rm` directly

## See Also

- `rm(1)` - Standard remove command
