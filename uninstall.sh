#!/bin/bash
# Uninstallation script for rmd
# Removes rmd and all associated files in a well-behaved Linux way
# Copyright (c) 2025 Andrew Turpin
# Licensed under MIT License

set -e

INSTALL_DIR="/usr/local/bin"
MAN_DIR="/usr/local/share/man/man1"
COMPLETION_DIR="/etc/bash_completion.d"
SCRIPT_NAME="rmd"
MAN_PAGE="rmd.1"
COMPLETION_FILE="rmd"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root for system-wide uninstall
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}Note: Some operations require root privileges.${NC}"
        echo "You may be prompted for sudo password."
        echo ""
    fi
}

# Remove main script
remove_script() {
    local script_path="$INSTALL_DIR/$SCRIPT_NAME"
    
    if [[ -f "$script_path" ]]; then
        if [[ -w "$INSTALL_DIR" ]] || sudo test -w "$INSTALL_DIR"; then
            if [[ -w "$INSTALL_DIR" ]]; then
                rm -f "$script_path"
            else
                sudo rm -f "$script_path"
            fi
            echo -e "${GREEN}✓ Removed $script_path${NC}"
            return 0
        else
            echo -e "${RED}✗ Cannot remove $script_path: Permission denied${NC}" >&2
            return 1
        fi
    else
        echo -e "${YELLOW}  $script_path not found (may already be removed)${NC}"
        return 0
    fi
}

# Remove man page
remove_man_page() {
    local man_path="$MAN_DIR/$MAN_PAGE"
    
    if [[ -f "$man_path" ]]; then
        if [[ -w "$MAN_DIR" ]] || sudo test -w "$MAN_DIR"; then
            if [[ -w "$MAN_DIR" ]]; then
                rm -f "$man_path"
            else
                sudo rm -f "$man_path"
            fi
            echo -e "${GREEN}✓ Removed $man_path${NC}"
            
            # Update man database if mandb is available
            if command -v mandb >/dev/null 2>&1; then
                if [[ $EUID -eq 0 ]]; then
                    mandb >/dev/null 2>&1 || true
                else
                    sudo mandb >/dev/null 2>&1 || true
                fi
                echo -e "${GREEN}✓ Updated man database${NC}"
            fi
            return 0
        else
            echo -e "${RED}✗ Cannot remove $man_path: Permission denied${NC}" >&2
            return 1
        fi
    else
        echo -e "${YELLOW}  $man_path not found (may already be removed)${NC}"
        return 0
    fi
}

# Remove bash completion
remove_completion() {
    local completion_path="$COMPLETION_DIR/$COMPLETION_FILE"
    
    if [[ -f "$completion_path" ]]; then
        if [[ -w "$COMPLETION_DIR" ]] || sudo test -w "$COMPLETION_DIR"; then
            if [[ -w "$COMPLETION_DIR" ]]; then
                rm -f "$completion_path"
            else
                sudo rm -f "$completion_path"
            fi
            echo -e "${GREEN}✓ Removed $completion_path${NC}"
            return 0
        else
            echo -e "${RED}✗ Cannot remove $completion_path: Permission denied${NC}" >&2
            return 1
        fi
    else
        echo -e "${YELLOW}  $completion_path not found (may already be removed)${NC}"
        return 0
    fi
}

# Check for aliases in shell config files
check_aliases() {
    local config_files=("$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.profile")
    local found_aliases=false
    
    echo -e "\n${YELLOW}Checking for aliases in shell configuration files...${NC}"
    
    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            if grep -q "alias.*rm.*=.*rmd" "$config_file" 2>/dev/null; then
                echo -e "${YELLOW}  Found alias in $config_file:${NC}"
                grep "alias.*rm.*=.*rmd" "$config_file" | sed 's/^/    /'
                found_aliases=true
            fi
        fi
    done
    
    if [[ "$found_aliases" == true ]]; then
        echo -e "\n${YELLOW}Note: You may want to remove the 'alias rm=rmd' line from your shell config files.${NC}"
        echo "  Edit the files listed above and remove or comment out the alias line."
    else
        echo -e "${GREEN}  No aliases found in shell configuration files.${NC}"
    fi
}

# Main uninstall function
main() {
    echo -e "${YELLOW}Uninstalling rmd...${NC}\n"
    
    check_permissions
    
    local errors=0
    
    # Remove files
    remove_script || ((errors++))
    remove_man_page || ((errors++))
    remove_completion || ((errors++))
    
    # Check for aliases
    check_aliases
    
    # Summary
    echo ""
    if [[ $errors -eq 0 ]]; then
        echo -e "${GREEN}Uninstallation complete!${NC}"
        echo ""
        echo "rmd has been removed from your system."
        echo "If you created an alias, remember to remove it from your shell config files."
        return 0
    else
        echo -e "${RED}Uninstallation completed with $errors error(s).${NC}" >&2
        echo "Some files may not have been removed. Check the messages above."
        return 1
    fi
}

# Run main function
main "$@"
