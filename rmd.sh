#!/bin/bash
# Lightweight wrapper for rm with safety features
# Copyright (c) 2025 Andrew Turpin
# Licensed under MIT License

set -euo pipefail

# Configuration
TRASH_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/Trash/files"
TRASH_INFO="${XDG_DATA_HOME:-$HOME/.local/share}/Trash/info"
PROTECTED_DIRS=("/bin" "/usr" "/etc" "/root" "/sbin" "/lib" "/lib64" "/opt" "/var" "/sys" "/proc" "/dev" "/boot")
CONFIG_PATTERNS=(".config" ".bashrc" ".bash_profile" ".zshrc" ".gitconfig" ".vimrc" ".vim" ".ssh" ".gnupg")

# Flags
FORCE=false
RECURSIVE=false
VERBOSE=false
SKIP_PROMPTS=false

# Initialize trash directories
init_trash() {
    mkdir -p "$TRASH_DIR" "$TRASH_INFO" 2>/dev/null || {
        echo "Error: Failed to create trash directories" >&2
        exit 3
    }
}

# Get absolute path of a file
get_absolute_path() {
    local path="$1"
    
    if [[ "$path" = /* ]]; then
        echo "$path"
    else
        local abs_path
        abs_path="$(cd "$(dirname "$path")" 2>/dev/null && pwd)/$(basename "$path")" || abs_path="$(pwd)/$path"
        echo "$abs_path"
    fi
}

# Check if path is a system file and return reason if protected
is_system_file() {
    local path="$1"
    local abs_path
    local reason=""
    
    # Get absolute path
    abs_path="$(get_absolute_path "$path")"
    
    # Check against protected directories
    for protected in "${PROTECTED_DIRS[@]}"; do
        if [[ "$abs_path" == "$protected"/* ]] || [[ "$abs_path" == "$protected" ]]; then
            reason="protected system directory ($protected)"
            echo "$reason"
            return 0
        fi
    done
    
    # Check if it's root's home directory
    if [[ "$abs_path" == "/root"/* ]] || [[ "$abs_path" == "/root" ]]; then
        reason="protected system directory (/root)"
        echo "$reason"
        return 0
    fi
    
    # Check if it's the current user's home directory (protect the home dir itself)
    if [[ "$abs_path" == "$HOME" ]]; then
        reason="protected home directory"
        echo "$reason"
        return 0
    fi
    
    return 1
}

# Check if file looks like a config file
is_config_file() {
    local filename="$1"
    local basename_file
    
    basename_file="$(basename "$filename")"
    
    # Check if hidden file
    if [[ "$basename_file" =~ ^\. ]]; then
        return 0
    fi
    
    # Check against config patterns
    for pattern in "${CONFIG_PATTERNS[@]}"; do
        if [[ "$filename" == *"$pattern"* ]]; then
            return 0
        fi
    done
    
    return 1
}

# Create .trashinfo metadata file
create_trashinfo() {
    local original_path="$1"
    local trash_name="$2"
    local info_file="$TRASH_INFO/${trash_name}.trashinfo"
    local deletion_date
    
    deletion_date="$(date -u +%Y-%m-%dT%H:%M:%S)"
    
    cat > "$info_file" <<EOF
[Trash Info]
Path=$original_path
DeletionDate=$deletion_date
EOF
}

# Move file to trash with conflict handling
move_to_trash() {
    local source="$1"
    local original_path
    local basename_file
    local dest="$TRASH_DIR/$(basename "$source")"
    local counter=1
    local final_dest="$dest"
    
    # Get absolute path of source
    original_path="$(get_absolute_path "$source")"
    
    basename_file="$(basename "$source")"
    
    # Handle filename conflicts
    while [[ -e "$final_dest" ]]; do
        final_dest="$TRASH_DIR/${basename_file}.${counter}"
        ((counter++))
    done
    
    # Move file/directory to trash (mv handles directories automatically)
    if mv "$source" "$final_dest" 2>/dev/null; then
        create_trashinfo "$original_path" "$(basename "$final_dest")"
        [[ "$VERBOSE" == true ]] && echo "Moved '$source' to trash"
        return 0
    else
        echo "Error: Failed to move '$source' to trash" >&2
        return 1
    fi
}

# Prompt user for action
prompt_user() {
    local filename="$1"
    local prompt_type="${2:-delete}"
    local response
    
    case "$prompt_type" in
        "folder")
            printf "%s is a directory, remove (Y/n/D): " "$filename" >&2
            ;;
        "config")
            printf "Warning: This appears to be a hidden/config file. Continue? (Y/n/D): " >&2
            ;;
        "delete")
            printf "Delete %s? (Y/n/D): " "$filename" >&2
            ;;
    esac
    
    # Flush stderr to ensure prompt appears before reading input
    # Try to read from terminal directly if available, otherwise use stdin
    if [[ -t 0 ]] && [[ -t 2 ]]; then
        read -r response < /dev/tty 2>/dev/null || read -r response
    else
        read -r response
    fi
    
    # Handle response (case-sensitive for 'D' - permanent delete requires explicit uppercase)
    case "${response,,}" in
        y|yes|"")
            echo "trash"
            ;;
        n|no)
            echo "cancel"
            ;;
        *)
            # Check for uppercase 'D' explicitly (permanent delete requires explicit uppercase)
            if [[ "$response" == "D" ]]; then
                echo "delete"
            else
                echo "cancel"
            fi
            ;;
    esac
}

# Process a single file
process_file() {
    local file="$1"
    local action
    local needs_recursive=false
    
    # Check if file exists
    if [[ ! -e "$file" ]]; then
        echo "rmd: cannot remove '$file': No such file or directory" >&2
        return 1
    fi
    
    # System file protection
    local protection_reason
    protection_reason="$(is_system_file "$file")"
    if [[ $? -eq 0 ]]; then
        echo "rmd: cannot remove '$file': $protection_reason" >&2
        return 2
    fi
    
    # Check if directory
    if [[ -d "$file" ]]; then
        # Always prompt for directories, even without -r flag
        if [[ "$FORCE" != true ]] && [[ "$SKIP_PROMPTS" != true ]]; then
            action="$(prompt_user "$file" "folder")"
        else
            # With -f flag, use trash but still need recursive flag
            if [[ "$RECURSIVE" == true ]]; then
                action="trash"
            else
                # Force mode without -r: still prompt or error?
                # For safety, require -r even with -f for directories
                echo "rmd: cannot remove '$file': Is a directory (use -r or -R flag to remove directories)" >&2
                return 1
            fi
        fi
        
        needs_recursive=true
    else
        # Config file warning
        if [[ "$FORCE" != true ]] && [[ "$SKIP_PROMPTS" != true ]] && is_config_file "$file"; then
            action="$(prompt_user "$file" "config")"
        elif [[ "$FORCE" != true ]] && [[ "$SKIP_PROMPTS" != true ]]; then
            action="$(prompt_user "$file" "delete")"
        else
            action="trash"
        fi
    fi
    
    case "$action" in
        "trash")
            # mv handles directories automatically, so no need to check -r flag
            # If user confirmed via prompt, proceed with move
            move_to_trash "$file"
            ;;
        "delete")
            # For directories, always use -r for permanent delete
            if [[ "$needs_recursive" == true ]]; then
                /bin/rm -r ${VERBOSE:+-v} "$file" 2>/dev/null || {
                    echo "rmd: cannot remove '$file': Failed to remove directory" >&2
                    return 1
                }
            else
                /bin/rm ${VERBOSE:+-v} "$file" 2>/dev/null || /bin/rm "$file"
            fi
            [[ "$VERBOSE" == true ]] && echo "Permanently deleted '$file'"
            ;;
        "cancel")
            [[ "$VERBOSE" == true ]] && echo "Cancelled deletion of '$file'"
            return 1
            ;;
    esac
}

# Show version
show_version() {
    echo "rmd 1.0.0"
    echo "Copyright (c) 2025 Andrew Turpin"
    echo "Licensed under MIT License"
}

# Show help
show_help() {
    cat <<EOF
Usage: rmd [OPTION]... FILE...
Remove (move to trash) files or directories.

Safety features:
  - Prevents deletion of system files
  - Warns about deleting folders and config files
  - Moves files to GNOME trash instead of permanent deletion

Options:
  -f, --force     Skip safety prompts (still uses trash)
  -r, -R, --recursive  Remove directories and their contents recursively
  -v, --verbose   Explain what is being done
  -h, --help      Display this help and exit
  --version       Display version information and exit

Prompts:
  Y    Move to trash (default)
  n    Cancel operation
  D    Permanent delete (bypass trash)

Examples:
  rmd file.txt              Move file to trash
  rmd -r directory/         Remove directory recursively
  rmd -f config.txt         Skip prompts, move to trash
  rmd file1 file2 file3     Remove multiple files

Note: This is a safety wrapper. Use 'rm' directly for permanent deletion.
EOF
}

# Parse arguments
parse_args() {
    local files=()
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            --version)
                show_version
                exit 0
                ;;
            -f|--force)
                FORCE=true
                SKIP_PROMPTS=true
                shift
                ;;
            -r|-R|--recursive)
                RECURSIVE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --)
                shift
                files+=("$@")
                break
                ;;
            -*)
                echo "rmd: invalid option -- '$1'" >&2
                echo "Try 'rmd --help' for more information." >&2
                exit 1
                ;;
            *)
                files+=("$1")
                shift
                ;;
        esac
    done
    
    if [[ ${#files[@]} -eq 0 ]]; then
        echo "rmd: missing operand" >&2
        echo "Try 'rmd --help' for more information." >&2
        exit 1
    fi
    
    # Process files
    local exit_code=0
    for file in "${files[@]}"; do
        process_file "$file" || exit_code=$?
    done
    
    return $exit_code
}

# Main
main() {
    init_trash
    parse_args "$@"
}

main "$@"
