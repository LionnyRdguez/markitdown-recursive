# Shared assertion helpers for MarkitdownRecursive tests.
#
# This file must be sourced by test files.
# Example:
#   source "${0:A:h:h}/test-helpers.zsh"

# Avoid redefining functions and resetting counters if sourced more than once.
if [[ -n "${MARKITDOWN_TEST_HELPERS_LOADED:-}" ]]; then
    return 0
fi

typeset -g MARKITDOWN_TEST_HELPERS_LOADED=1

# Global assertion counters.
typeset -gi MR_TEST_ASSERTIONS_TOTAL=0
typeset -gi MR_TEST_ASSERTIONS_PASSED=0
typeset -gi MR_TEST_ASSERTIONS_FAILED=0


# Records an assertion result and updates the counters.
_mr_test_record() {
    local result="$1"
    local message="$2"

    (( ++MR_TEST_ASSERTIONS_TOTAL ))

    if [[ "$result" == "PASS" ]]; then
        (( ++MR_TEST_ASSERTIONS_PASSED ))
        print -- "[PASS] $message"
        return 0
    fi

    (( ++MR_TEST_ASSERTIONS_FAILED ))
    print -u2 -- "[FAIL] $message"
    return 1
}


# Checks whether two values are equal.
# Usage: assert_equal EXPECTED ACTUAL [MESSAGE]
assert_equal() {
    if (( $# < 2 || $# > 3 )); then
        _mr_test_record "FAIL" \
            "assert_equal requires EXPECTED, ACTUAL and an optional MESSAGE"
        return 2
    fi

    local expected="$1"
    local actual="$2"
    local message

    if [[ "$expected" == "$actual" ]]; then
        message="${3:-Values are equal}"
        _mr_test_record "PASS" "$message"
    else
        message="${3:-Expected ${(q)expected}, received ${(q)actual}}"
        _mr_test_record "FAIL" "$message"
    fi
}


# Checks whether two values are different.
# Usage: assert_not_equal VALUE1 VALUE2 [MESSAGE]
assert_not_equal() {
    if (( $# < 2 || $# > 3 )); then
        _mr_test_record "FAIL" \
            "assert_not_equal requires VALUE1, VALUE2 and an optional MESSAGE"
        return 2
    fi

    local value1="$1"
    local value2="$2"
    local message

    if [[ "$value1" != "$value2" ]]; then
        message="${3:-Values are different}"
        _mr_test_record "PASS" "$message"
    else
        message="${3:-Both values are ${(q)value1}}"
        _mr_test_record "FAIL" "$message"
    fi
}


# Checks whether a string contains a literal substring.
# Usage: assert_contains NEEDLE HAYSTACK [MESSAGE]
assert_contains() {
    if (( $# < 2 || $# > 3 )); then
        _mr_test_record "FAIL" \
            "assert_contains requires NEEDLE, HAYSTACK and an optional MESSAGE"
        return 2
    fi

    local needle="$1"
    local haystack="$2"
    local message

    if [[ "$haystack" == *"$needle"* ]]; then
        message="${3:-Expected text was found}"
        _mr_test_record "PASS" "$message"
    else
        message="${3:-Expected text was not found: ${(q)needle}}"
        _mr_test_record "FAIL" "$message"
    fi
}


# Checks that a string does not contain a literal substring.
# Usage: assert_not_contains NEEDLE HAYSTACK [MESSAGE]
assert_not_contains() {
    if (( $# < 2 || $# > 3 )); then
        _mr_test_record "FAIL" \
            "assert_not_contains requires NEEDLE, HAYSTACK and an optional MESSAGE"
        return 2
    fi

    local needle="$1"
    local haystack="$2"
    local message

    if [[ "$haystack" != *"$needle"* ]]; then
        message="${3:-Unexpected text was not found}"
        _mr_test_record "PASS" "$message"
    else
        message="${3:-Unexpected text was found: ${(q)needle}}"
        _mr_test_record "FAIL" "$message"
    fi
}


# Checks whether a regular file exists.
# Symbolic links pointing to regular files also satisfy this assertion.
# Usage: assert_file_exists PATH [MESSAGE]
assert_file_exists() {
    if (( $# < 1 || $# > 2 )); then
        _mr_test_record "FAIL" \
            "assert_file_exists requires PATH and an optional MESSAGE"
        return 2
    fi

    local path="$1"
    local message

    if [[ -f "$path" ]]; then
        message="${2:-File exists: ${(q)path}}"
        _mr_test_record "PASS" "$message"
    else
        message="${2:-File does not exist: ${(q)path}}"
        _mr_test_record "FAIL" "$message"
    fi
}


# Checks that a file does not exist, including a dangling symbolic link.
# Usage: assert_file_not_exists PATH [MESSAGE]
assert_file_not_exists() {
    if (( $# < 1 || $# > 2 )); then
        _mr_test_record "FAIL" \
            "assert_file_not_exists requires PATH and an optional MESSAGE"
        return 2
    fi

    local path="$1"
    local message

    if [[ ! -e "$path" && ! -L "$path" ]]; then
        message="${2:-File does not exist: ${(q)path}}"
        _mr_test_record "PASS" "$message"
    else
        message="${2:-File unexpectedly exists: ${(q)path}}"
        _mr_test_record "FAIL" "$message"
    fi
}


# Checks whether a directory exists.
# Usage: assert_directory_exists PATH [MESSAGE]
assert_directory_exists() {
    if (( $# < 1 || $# > 2 )); then
        _mr_test_record "FAIL" \
            "assert_directory_exists requires PATH and an optional MESSAGE"
        return 2
    fi

    local path="$1"
    local message

    if [[ -d "$path" ]]; then
        message="${2:-Directory exists: ${(q)path}}"
        _mr_test_record "PASS" "$message"
    else
        message="${2:-Directory does not exist: ${(q)path}}"
        _mr_test_record "FAIL" "$message"
    fi
}


# Checks that a directory does not exist.
# Usage: assert_directory_not_exists PATH [MESSAGE]
assert_directory_not_exists() {
    if (( $# < 1 || $# > 2 )); then
        _mr_test_record "FAIL" \
            "assert_directory_not_exists requires PATH and an optional MESSAGE"
        return 2
    fi

    local path="$1"
    local message

    if [[ ! -d "$path" ]]; then
        message="${2:-Directory does not exist: ${(q)path}}"
        _mr_test_record "PASS" "$message"
    else
        message="${2:-Directory unexpectedly exists: ${(q)path}}"
        _mr_test_record "FAIL" "$message"
    fi
}


# Checks whether a path exists, including symbolic links.
# Usage: assert_path_exists PATH [MESSAGE]
assert_path_exists() {
    if (( $# < 1 || $# > 2 )); then
        _mr_test_record "FAIL" \
            "assert_path_exists requires PATH and an optional MESSAGE"
        return 2
    fi

    local path="$1"
    local message

    if [[ -e "$path" || -L "$path" ]]; then
        message="${2:-Path exists: ${(q)path}}"
        _mr_test_record "PASS" "$message"
    else
        message="${2:-Path does not exist: ${(q)path}}"
        _mr_test_record "FAIL" "$message"
    fi
}


# Checks the exit code of a command.
# Command output is suppressed.
# Usage: assert_exit_code EXPECTED_STATUS COMMAND [ARGUMENTS...]
assert_exit_code() {
    if (( $# < 2 )); then
        _mr_test_record "FAIL" \
            "assert_exit_code requires EXPECTED_STATUS and a COMMAND"
        return 2
    fi

    local expected="$1"
    shift

    local actual
    local command_description="$*"
    local message

    if ( "$@" ) >/dev/null 2>&1; then
        actual=0
    else
        actual=$?
    fi

    if [[ "$expected" == "$actual" ]]; then
        message="Command returned expected exit code $expected: $command_description"
        _mr_test_record "PASS" "$message"
    else
        message="Command returned $actual instead of $expected: $command_description"
        _mr_test_record "FAIL" "$message"
    fi
}


# Prints the assertion summary.
# Returns 0 if all assertions passed, 1 if any failed,
# or 2 if no assertions were executed.
# This should be the last command in each test file.
test_summary() {
    print ""
    print "----------------------------------------"
    print " Test Assertions Summary"
    print "----------------------------------------"
    print "Total:  $MR_TEST_ASSERTIONS_TOTAL"
    print "Passed: $MR_TEST_ASSERTIONS_PASSED"
    print "Failed: $MR_TEST_ASSERTIONS_FAILED"
    print "----------------------------------------"

    if (( MR_TEST_ASSERTIONS_TOTAL == 0 )); then
        print -u2 -- "Error: No assertions were executed."
        return 2
    fi

    if (( MR_TEST_ASSERTIONS_FAILED > 0 )); then
        return 1
    fi

    return 0
}
