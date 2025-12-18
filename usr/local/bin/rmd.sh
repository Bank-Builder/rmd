#!/bin/bash
# Lightweight wrapper for rm with safety features

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

# Check if path is a system file
is_system_file() {
    local path="$1"
    local abs_path
    
    # Get absolute path
    if [[ "$path" = /* ]]; then
        abs_path="$path"
    else
        abs_path="$(cd "$(dirname "$path")" 2>/dev/null && pwd)/$(basename "$path")" || abs_path="$(pwd)/$path"
    fi
    
    # Check against protected directories
    for protected in "${PROTECTED_DIRS[@]}"; do
        if [[ "$abs_path" == "$protected"/* ]] || [[ "$abs_path" == "$protected" ]]; then
            return 0
        fi
    done
    
    # Check if it's root's home directory
    if [[ "$abs_path" == "/root"/* ]] || [[ "$abs_path" == "/root" ]]; then
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
    if [[ "$source" = /* ]]; then
        original_path="$source"
    else
        original_path="$(cd "$(dirname "$source")" 2>/dev/null && pwd)/$(basename "$source")" || original_path="$(pwd)/$source"
    fi
    
    basename_file="$(basename "$source")"
    
    # Handle filename conflicts
    while [[ -e "$final_dest" ]]; do
        final_dest="$TRASH_DIR/${basename_file}.${counter}"
        ((counter++))
    done
    
    # Move file/directory to trash
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
            echo -n "This is a folder. Are you sure you want to delete it? (Y/n/D): "
            ;;
        "config")
            echo -n "Warning: This appears to be a hidden/config file. Continue? (Y/n/D): "
            ;;
        "delete")
            echo -n "Delete $filename? (Y/n/D): "
            ;;
    esac
    
    read -r response
    
    case "${response,,}" in
        y|yes|"")
            echo "trash"
            ;;
        n|no)
            echo "cancel"
            ;;
        d)
            echo "delete"
            ;;
        *)
            echo "cancel"
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
    if is_system_file "$file"; then
        echo "rmd: cannot remove '$file': System file protection enabled" >&2
        return 2
    fi
    
    # Check if directory
    if [[ -d "$file" ]]; then
        if [[ "$FORCE" != true ]] && [[ "$SKIP_PROMPTS" != true ]]; then
            action="$(prompt_user "$file" "folder")"
        else
            action="trash"
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
            if [[ "$needs_recursive" == true ]] && [[ "$RECURSIVE" != true ]]; then
                echo "rmd: cannot remove '$file': Is a directory (use -r flag)" >&2
                return 1
            fi
            move_to_trash "$file"
            ;;
        "delete")
            if [[ "$needs_recursive" == true ]] && [[ "$RECURSIVE" != true ]]; then
                /bin/rm -r "$file" 2>/dev/null || {
                    echo "rmd: cannot remove '$file': Is a directory (use -r flag)" >&2
                    return 1
                }
            else
                /bin/rm ${RECURSIVE:+-r} ${VERBOSE:+-v} "$file" 2>/dev/null || /bin/rm "$file"
            fi
            [[ "$VERBOSE" == true ]] && echo "Permanently deleted '$file'"
            ;;
        "cancel")
            [[ "$VERBOSE" == true ]] && echo "Cancelled deletion of '$file'"
            return 1
            ;;
    esac
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
