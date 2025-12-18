# Quick Testing Guide

## Safest Method: Automated Test Suite

Run the comprehensive test suite:

```bash
./test_rmd.sh
```

This will:
- Create an isolated test environment
- Run 15+ automated tests
- Show pass/fail results
- Automatically clean up

## Quick Manual Test

For a quick manual test in an isolated environment:

```bash
# Create test directory
TEST_DIR="/tmp/rmd_quick_test_$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Set up isolated trash
export XDG_DATA_HOME="$TEST_DIR/.test_trash"
export HOME="$TEST_DIR/home"
mkdir -p "$HOME"

# Create test files
echo "test1" > file1.txt
echo "test2" > .hidden
mkdir testdir

# Test the script (adjust path as needed)
/path/to/rmd.sh file1.txt
# Answer: Y (to move to trash)

# Check trash
ls -la "$XDG_DATA_HOME/Trash/files/"

# Cleanup
cd /
rm -rf "$TEST_DIR"
```

## What Gets Tested

The automated test suite verifies:
1. Help command
2. Non-existent file handling
3. Regular file deletion (trash)
4. Cancellation (n response)
5. Permanent delete (D response)
6. Force mode (-f)
7. Directory deletion (with/without -r)
8. System file protection
9. Home directory protection
10. Hidden file warnings
11. Multiple file handling
12. Verbose mode
13. Trash info file creation
14. Filename conflict handling

## Safety Features

- All tests run in `/tmp/rmd_test_*` (isolated)
- Uses separate test trash location
- Never touches your real files
- Automatic cleanup on exit
- Can be interrupted safely (Ctrl+C)
