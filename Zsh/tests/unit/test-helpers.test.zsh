
#!/usr/bin/env zsh

# Unit tests for the shared test helper functions.

emulate -LR zsh

TEST_DIR="${0:A:h:h}"
PROJECT_ROOT="${TEST_DIR:h:h}"

HELPERS_PATH="$TEST_DIR/test-helpers.zsh"
SCRIPT_PATH="$PROJECT_ROOT/Zsh/MarkitdownRecursive.zsh"

source "$HELPERS_PATH"


# Executes an assertion in an isolated Zsh process and verifies
# that it returns a failure status.
assert_helper_failure() {
    assert_exit_code 1 zsh -f -c \
        'source "$1"; shift; "$@"' \
        helper-test "$HELPERS_PATH" "$@"
}


# --------------------------------------------------
# Positive assertions
# --------------------------------------------------

# Value assertions.
assert_equal "hello" "hello" "assert_equal accepts equal values"
assert_not_equal "hello" "world" "assert_not_equal accepts different values"

# String assertions.
assert_contains "world" "hello world" "assert_contains finds a substring"
assert_not_contains "missing" "hello world" "assert_not_contains rejects absent substrings"

# File assertions.
assert_file_exists "$SCRIPT_PATH" "assert_file_exists detects existing files"
assert_file_not_exists "$TEST_DIR/nonexistent-file" "assert_file_not_exists detects missing files"

# Directory assertions.
assert_directory_exists "$TEST_DIR" "assert_directory_exists detects existing directories"
assert_directory_not_exists "$TEST_DIR/nonexistent-directory" "assert_directory_not_exists detects missing directories"

# General path assertion.
assert_path_exists "$HELPERS_PATH" "assert_path_exists detects existing paths"

# Exit code assertions.
assert_exit_code 0 true
assert_exit_code 7 sh -c "exit 7"


# --------------------------------------------------
# Negative assertions
# --------------------------------------------------

# Value assertions must reject incorrect conditions.
assert_helper_failure assert_equal "expected" "actual"
assert_helper_failure assert_not_equal "same" "same"

# String assertions must detect incorrect conditions.
assert_helper_failure assert_contains "missing" "hello world"
assert_helper_failure assert_not_contains "hello" "hello world"

# File assertions must detect incorrect conditions.
assert_helper_failure assert_file_exists "$TEST_DIR/nonexistent-file"
assert_helper_failure assert_file_not_exists "$HELPERS_PATH"

# Directory assertions must detect incorrect conditions.
assert_helper_failure assert_directory_exists "$TEST_DIR/nonexistent-directory"
assert_helper_failure assert_directory_not_exists "$TEST_DIR"

# General path assertion must reject missing paths.
assert_helper_failure assert_path_exists "$TEST_DIR/nonexistent-path"

# Exit code assertion must reject unexpected command statuses.
assert_helper_failure assert_exit_code 0 false


# --------------------------------------------------
# Summary and argument validation
# --------------------------------------------------

# An empty test summary must not report success.
assert_exit_code 2 zsh -f -c \
    'source "$1"; test_summary' \
    helper-test "$HELPERS_PATH"

# A summary containing failed assertions must return status 1.
assert_exit_code 1 zsh -f -c \
    'source "$1"; assert_equal expected actual; test_summary' \
    helper-test "$HELPERS_PATH"

# Incorrect assertion arguments must return status 2.
assert_exit_code 2 zsh -f -c \
    'source "$1"; assert_equal only-one-argument' \
    helper-test "$HELPERS_PATH"


# Report the results.
test_summary
