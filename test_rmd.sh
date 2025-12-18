#!/bin/bash
# Safe testing script for rmd.sh
# This script creates an isolated test environment to safely test rmd functionality
# Copyright (c) 2025 Andrew Turpin
# Licensed under MIT License

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test configuration
TEST_DIR="/tmp/rmd_test_$$"
TEST_TRASH="$TEST_DIR/.test_trash"
RMD_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/rmd.sh"
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

# Store original environment variables
ORIG_HOME="${HOME:-}"
ORIG_XDG_DATA_HOME="${XDG_DATA_HOME:-}"

# Create isolated test environment
setup_test_env() {
    echo -e "${YELLOW}Setting up isolated test environment...${NC}"
    
    # Create test directory
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
    
    # Create fake home directory in test environment
    mkdir -p "$TEST_DIR/home"
    export HOME="$TEST_DIR/home"
    
    # Set XDG_DATA_HOME to point to our test location
    # This will make trash be at $TEST_DIR/.test_trash/Trash/files
    mkdir -p "$TEST_DIR/.test_trash"
    export XDG_DATA_HOME="$TEST_DIR/.test_trash"
    
    # Create test trash directories (rmd.sh will create these, but create them here too)
    mkdir -p "$XDG_DATA_HOME/Trash/files" "$XDG_DATA_HOME/Trash/info"
    
    # Update TEST_TRASH to match actual location
    TEST_TRASH="$XDG_DATA_HOME/Trash"
    
    # Create a modified rmd script that uses test environment
    {
        cat <<EOF
#!/bin/bash
# Test version of rmd that uses isolated trash
export XDG_DATA_HOME="$TEST_DIR/.test_trash"
export HOME="$TEST_DIR/home"
EOF
        cat "$RMD_SCRIPT"
    } > "$TEST_DIR/rmd_test.sh"
    chmod +x "$TEST_DIR/rmd_test.sh"
    
    echo -e "${GREEN}Test environment ready at: $TEST_DIR${NC}"
}

# Cleanup test environment
cleanup() {
    echo -e "\n${YELLOW}Cleaning up test environment...${NC}"
    
    # Restore original environment variables
    if [[ -n "$ORIG_HOME" ]]; then
        export HOME="$ORIG_HOME"
    else
        unset HOME
    fi
    
    if [[ -n "$ORIG_XDG_DATA_HOME" ]]; then
        export XDG_DATA_HOME="$ORIG_XDG_DATA_HOME"
    else
        unset XDG_DATA_HOME
    fi
    
    # Remove test directory
    cd /
    rm -rf "$TEST_DIR"
    
    echo -e "${GREEN}Cleanup complete${NC}"
}

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    local description="$4"
    
    ((TEST_COUNT++))
    echo -e "\n${YELLOW}Test $TEST_COUNT: $test_name${NC}"
    echo "  Description: $description"
    echo "  Command: $test_command"
    
    cd "$TEST_DIR"
    
    # Run test and capture result
    local result
    if eval "$test_command" > "$TEST_DIR/test_output_$TEST_COUNT.txt" 2>&1; then
        result="pass"
    else
        result="fail"
    fi
    
    # Check if result matches expected
    if [[ "$result" == "$expected_result" ]]; then
        echo -e "  ${GREEN}✓ PASS${NC}"
        ((PASS_COUNT++))
        return 0
    else
        echo -e "  ${RED}✗ FAIL${NC} (Expected: $expected_result, Got: $result)"
        echo "  Output:"
        sed 's/^/    /' "$TEST_DIR/test_output_$TEST_COUNT.txt"
        ((FAIL_COUNT++))
        return 1
    fi
}

# Test file creation helper
create_test_file() {
    local filename="$1"
    local content="${2:-test content}"
    echo "$content" > "$TEST_DIR/$filename"
}

create_test_dir() {
    local dirname="$1"
    mkdir -p "$TEST_DIR/$dirname"
    echo "nested file" > "$TEST_DIR/$dirname/nested.txt"
}

# Main test suite
run_tests() {
    echo -e "${YELLOW}=== Running rmd Test Suite ===${NC}\n"
    
    # Test 1: Help command
    run_test "help_command" \
        "$TEST_DIR/rmd_test.sh --help | grep -q 'Usage:'" \
        "pass" \
        "Help command should display usage"
    
    # Test 2: Delete non-existent file
    run_test "nonexistent_file" \
        "$TEST_DIR/rmd_test.sh nonexistent.txt 2>&1 | grep -q 'No such file'" \
        "pass" \
        "Should error on non-existent file"
    
    # Test 3: Delete regular file (with Y response)
    create_test_file "test1.txt"
    run_test "delete_regular_file" \
        "echo 'Y' | $TEST_DIR/rmd_test.sh test1.txt && [[ ! -f test1.txt ]] && [[ -f $TEST_TRASH/files/test1.txt ]]" \
        "pass" \
        "Should move regular file to trash"
    
    # Test 4: Cancel deletion (with n response)
    create_test_file "test2.txt"
    run_test "cancel_deletion" \
        "echo 'n' | $TEST_DIR/rmd_test.sh test2.txt && [[ -f test2.txt ]]" \
        "pass" \
        "Should cancel deletion when user says no"
    
    # Test 5: Permanent delete (with D response)
    create_test_file "test3.txt"
    run_test "permanent_delete" \
        "echo 'D' | $TEST_DIR/rmd_test.sh test3.txt && [[ ! -f test3.txt ]] && [[ ! -f $TEST_TRASH/files/test3.txt ]]" \
        "pass" \
        "Should permanently delete when user chooses D"
    
    # Test 6: Force mode (-f)
    create_test_file "test4.txt"
    run_test "force_mode" \
        "$TEST_DIR/rmd_test.sh -f test4.txt && [[ ! -f test4.txt ]] && [[ -f $TEST_TRASH/files/test4.txt ]]" \
        "pass" \
        "Force mode should skip prompts and move to trash"
    
    # Test 7: Delete directory without -r flag
    create_test_dir "testdir1"
    run_test "directory_without_r" \
        "$TEST_DIR/rmd_test.sh testdir1 2>&1 | grep -q 'Is a directory'" \
        "pass" \
        "Should error when deleting directory without -r"
    
    # Test 8: Delete directory with -r flag
    create_test_dir "testdir2"
    run_test "delete_directory_with_r" \
        "echo 'Y' | $TEST_DIR/rmd_test.sh -r testdir2 && [[ ! -d testdir2 ]]" \
        "pass" \
        "Should delete directory with -r flag"
    
    # Test 9: System file protection
    run_test "system_file_protection" \
        "$TEST_DIR/rmd_test.sh /bin/ls 2>&1 | grep -q 'System file protection'" \
        "pass" \
        "Should block deletion of system files"
    
    # Test 10: Home directory protection
    run_test "home_directory_protection" \
        "$TEST_DIR/rmd_test.sh $TEST_DIR/home 2>&1 | grep -q 'System file protection'" \
        "pass" \
        "Should block deletion of home directory"
    
    # Test 11: Hidden file warning
    create_test_file ".hidden"
    run_test "hidden_file_warning" \
        "echo 'Y' | $TEST_DIR/rmd_test.sh .hidden 2>&1 | grep -q 'hidden/config file'" \
        "pass" \
        "Should warn about hidden/config files"
    
    # Test 12: Multiple files
    create_test_file "multi1.txt"
    create_test_file "multi2.txt"
    create_test_file "multi3.txt"
    run_test "multiple_files" \
        "echo -e 'Y\nY\nY' | $TEST_DIR/rmd_test.sh multi1.txt multi2.txt multi3.txt && [[ ! -f multi1.txt ]] && [[ ! -f multi2.txt ]] && [[ ! -f multi3.txt ]]" \
        "pass" \
        "Should handle multiple files"
    
    # Test 13: Verbose mode
    create_test_file "verbose.txt"
    run_test "verbose_mode" \
        "echo 'Y' | $TEST_DIR/rmd_test.sh -v verbose.txt 2>&1 | grep -q 'Moved'" \
        "pass" \
        "Verbose mode should show operation details"
    
    # Test 14: Trash info file creation
    create_test_file "trashinfo_test.txt"
    run_test "trashinfo_creation" \
        "echo 'Y' | $TEST_DIR/rmd_test.sh trashinfo_test.txt && [[ -f $TEST_TRASH/info/trashinfo_test.txt.trashinfo ]]" \
        "pass" \
        "Should create .trashinfo metadata file"
    
    # Test 15: Filename conflict handling
    create_test_file "conflict.txt"
    echo 'Y' | $TEST_DIR/rmd_test.sh conflict.txt >/dev/null 2>&1
    create_test_file "conflict.txt"
    run_test "filename_conflict" \
        "echo 'Y' | $TEST_DIR/rmd_test.sh conflict.txt && ls $TEST_TRASH/files/conflict.txt* | wc -l | grep -q '^2'" \
        "pass" \
        "Should handle filename conflicts in trash"
    
    # Test 16: File with spaces in name
    create_test_file "file with spaces.txt"
    run_test "file_with_spaces" \
        "echo 'Y' | $TEST_DIR/rmd_test.sh 'file with spaces.txt' && [[ ! -f 'file with spaces.txt' ]] && [[ -f \"$TEST_TRASH/files/file with spaces.txt\" ]]" \
        "pass" \
        "Should handle files with spaces in names"
    
    # Test 17: Symlink handling
    create_test_file "symlink_target.txt"
    ln -s symlink_target.txt "$TEST_DIR/symlink.txt"
    run_test "symlink_handling" \
        "echo 'Y' | $TEST_DIR/rmd_test.sh symlink.txt && [[ ! -L symlink.txt ]] && [[ -f symlink_target.txt ]]" \
        "pass" \
        "Should handle symlinks correctly"
    
    # Test 18: Version flag
    run_test "version_flag" \
        "$TEST_DIR/rmd_test.sh --version | grep -q 'rmd 1.0.0'" \
        "pass" \
        "Should display version information"
}

# Print summary
print_summary() {
    echo -e "\n${YELLOW}=== Test Summary ===${NC}"
    echo -e "Total tests: $TEST_COUNT"
    echo -e "${GREEN}Passed: $PASS_COUNT${NC}"
    if [[ $FAIL_COUNT -gt 0 ]]; then
        echo -e "${RED}Failed: $FAIL_COUNT${NC}"
    else
        echo -e "${GREEN}Failed: $FAIL_COUNT${NC}"
    fi
    
    if [[ $FAIL_COUNT -eq 0 ]]; then
        echo -e "\n${GREEN}All tests passed! ✓${NC}"
        return 0
    else
        echo -e "\n${RED}Some tests failed. Review output above.${NC}"
        return 1
    fi
}

# Main execution
main() {
    # Trap to ensure cleanup on exit
    trap cleanup EXIT
    
    setup_test_env
    run_tests
    print_summary
    
    exit $?
}

main "$@"
