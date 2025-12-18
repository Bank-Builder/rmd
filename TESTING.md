# Safe Testing Guide for rmd.sh

Testing file deletion tools can be dangerous. This guide provides safe methods to test `rmd.sh` without risking your actual files.

## Quick Start: Automated Test Suite

The safest way to test is using the provided test script:

```bash
./test_rmd.sh
```

This script:
- Creates an isolated test environment in `/tmp/rmd_test_*`
- Uses a separate test trash location
- Tests all major functionality
- Automatically cleans up after testing
- Provides pass/fail results

## Manual Testing Methods

### Method 1: Isolated Test Directory

Create a dedicated test directory:

```bash
# Create test environment
TEST_DIR="/tmp/rmd_manual_test"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Create test files
echo "test1" > file1.txt
echo "test2" > file2.txt
mkdir testdir
echo "nested" > testdir/nested.txt

# Test with modified trash location
export XDG_DATA_HOME="$TEST_DIR/.test_trash"
mkdir -p "$XDG_DATA_HOME/Trash/files" "$XDG_DATA_HOME/Trash/info"

# Test the script (pointing to your rmd.sh)
/path/to/rmd.sh file1.txt

# Verify results
ls -la "$XDG_DATA_HOME/Trash/files/"

# Cleanup when done
cd /
rm -rf "$TEST_DIR"
```

### Method 2: Use a VM or Container

For the safest testing:

1. **Virtual Machine**: Use a disposable VM (VirtualBox, QEMU, etc.)
2. **Docker Container**: 
   ```bash
   docker run -it --rm -v /path/to/rmd.sh:/usr/local/bin/rmd:ro ubuntu:latest bash
   ```
3. **chroot Environment**: Create a chroot jail for testing

### Method 3: Test with Mock rm Command

Create a wrapper that logs instead of deleting:

```bash
# Create safe test wrapper
cat > /tmp/safe_rm_test.sh << 'EOF'
#!/bin/bash
# Mock rm that just logs
echo "WOULD DELETE: $@" >> /tmp/rm_test.log
EOF
chmod +x /tmp/safe_rm_test.sh

# Temporarily modify rmd.sh to use mock rm
# (Replace /bin/rm calls with /tmp/safe_rm_test.sh)
```

### Method 4: Use Version Control

Test in a git repository:

```bash
# Create test repo
mkdir rmd_test_repo && cd rmd_test_repo
git init
echo "test" > test.txt
git add test.txt
git commit -m "Test file"

# Test deletion
rmd.sh test.txt

# Verify and restore if needed
git status
git checkout -- test.txt  # Restore if needed
```

## Testing Checklist

When testing manually, verify:

- [ ] Regular file deletion (moves to trash)
- [ ] Directory deletion with -r flag
- [ ] Cancellation (n response)
- [ ] Permanent delete (D response)
- [ ] Force mode (-f flag)
- [ ] System file protection
- [ ] Home directory protection
- [ ] Hidden file warnings
- [ ] Multiple file handling
- [ ] Verbose mode output
- [ ] Trash info file creation
- [ ] Filename conflict handling
- [ ] Help command
- [ ] Error messages for invalid operations

## Safety Tips

1. **Never test on production systems** without backups
2. **Use isolated directories** (`/tmp` is good for testing)
3. **Set up separate trash location** for testing
4. **Test with non-critical files first**
5. **Verify trash contents** before permanent deletion
6. **Use the automated test suite** when possible
7. **Test in a VM/container** for maximum safety

## Recovering from Accidental Deletion

If you accidentally delete something during testing:

1. **Check GNOME Trash**: Files moved to trash can be restored
   ```bash
   ls ~/.local/share/Trash/files/
   ```
2. **Restore from trash**: Use your file manager or:
   ```bash
   # Find the .trashinfo file
   cat ~/.local/share/Trash/info/FILENAME.trashinfo
   # Restore manually using the Path= value
   ```
3. **If permanently deleted**: Use file recovery tools like `testdisk`, `photorec`, or `extundelete` (for ext filesystems)

## Test Environment Variables

You can modify the test environment:

```bash
# Use custom trash location
export XDG_DATA_HOME="/tmp/my_test_trash"

# Use custom home for testing
export HOME="/tmp/test_home"
```

## Continuous Testing

For development, consider:

1. Running `test_rmd.sh` before each commit
2. Adding tests to CI/CD pipeline
3. Using test-driven development for new features

## Reporting Issues

If you find issues during testing:

1. Note the exact command that caused the issue
2. Capture error output
3. Check the test environment setup
4. Verify script version and system compatibility
