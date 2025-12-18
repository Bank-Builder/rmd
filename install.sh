#!/bin/bash
# Installation script for rmd
# Copyright (c) 2025 Andrew Turpin
# Licensed under MIT License

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/usr/local/bin"
MAN_DIR="/usr/local/share/man/man1"
COMPLETION_DIR="/etc/bash_completion.d"

echo "Installing rmd..."

# Check if rmd.sh exists
if [[ ! -f "$SCRIPT_DIR/rmd.sh" ]]; then
    echo "Error: rmd.sh not found in $SCRIPT_DIR" >&2
    exit 1
fi

# Backup existing installation if present
if [[ -f "$INSTALL_DIR/rmd" ]]; then
    echo "  Backing up existing $INSTALL_DIR/rmd to ${INSTALL_DIR}/rmd.backup"
    sudo cp "$INSTALL_DIR/rmd" "${INSTALL_DIR}/rmd.backup" 2>/dev/null || true
fi

# Install main script
sudo cp "$SCRIPT_DIR/rmd.sh" "$INSTALL_DIR/rmd"
sudo chmod +x "$INSTALL_DIR/rmd"
echo "  Installed $INSTALL_DIR/rmd"

# Install man page
if [[ -f "$SCRIPT_DIR/usr/local/share/man/man1/rmd.1" ]]; then
    sudo mkdir -p "$MAN_DIR"
    sudo cp "$SCRIPT_DIR/usr/local/share/man/man1/rmd.1" "$MAN_DIR/"
    echo "  Installed man page"
else
    echo "  Warning: Man page not found, skipping..." >&2
fi

# Install bash completion
if [[ -d "$COMPLETION_DIR" ]]; then
    if [[ -f "$SCRIPT_DIR/rmd.bash-completion" ]]; then
        sudo cp "$SCRIPT_DIR/rmd.bash-completion" "$COMPLETION_DIR/rmd"
        echo "  Installed bash completion"
    else
        echo "  Warning: Bash completion file not found, skipping..." >&2
    fi
else
    echo "  Note: Bash completion directory not found, skipping..." >&2
fi

# Update man database
if command -v mandb >/dev/null 2>&1; then
    sudo mandb >/dev/null 2>&1 || true
    echo "  Updated man database"
fi

echo ""
echo "Installation complete!"
echo ""
echo "To use rmd, you can:"
echo "  1. Run directly: rmd file.txt"
echo "  2. Create alias: alias rm='rmd' (add to ~/.bashrc or ~/.zshrc)"
echo ""
