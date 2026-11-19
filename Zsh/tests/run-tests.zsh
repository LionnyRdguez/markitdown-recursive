#!/usr/bin/env zsh
#!/usr/bin/env zsh

# Main test runner for MarkitdownRecursive.
# Discovers and executes unit and integration tests.

emulate -LR zsh

setopt null_glob

SCRIPT_DIR="${0:A:h}"
TEST_DIR="$SCRIPT_DIR"
PROJECT_ROOT="${TEST_DIR:h:h}"

typeset -a test_files

typeset -i TOTAL=0
typeset -i PASSED=0
typeset -i FAILED=0

print "========================================"
print " MarkitdownRecursive - Test Suite"
print "========================================"
print ""

# Collect all test files from the supported test directories.
test_files=(
    "$TEST_DIR"/unit/*.test.zsh
    "$TEST_DIR"/integration/*.test.zsh
)

# Prevent an empty test suite from being reported as successful.
if (( ${#test_files[@]} == 0 )); then
    print -u2 -- "Error: No test files were found."
    print -u2 -- "Expected files in:"
    print -u2 -- "  $TEST_DIR/unit/"
    print -u2 -- "  $TEST_DIR/integration/"
    exit 2
fi

# Run tests from the project root for consistent relative paths.
if ! cd "$PROJECT_ROOT"; then
    print -u2 -- "Error: Could not access project root: $PROJECT_ROOT"
    exit 2
fi

for test_file in "${test_files[@]}"; do
    (( ++TOTAL ))

    test_name="${test_file#$TEST_DIR/}"

    print "Running: $test_name"

    if zsh -f "$test_file"; then
        (( ++PASSED ))
        print "[PASS] $test_name"
    else
        (( ++FAILED ))
        print "[FAIL] $test_name"
    fi

    print ""
done

print "========================================"
print " Test Summary"
print "========================================"
print "Total:  $TOTAL"
print "Passed: $PASSED"
print "Failed: $FAILED"
print "========================================"

if (( FAILED > 0 )); then
    exit 1
fi

exit 0
