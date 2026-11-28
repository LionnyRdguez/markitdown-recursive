#!/usr/bin/env zsh

# Integration tests for the MarkitdownRecursive command-line interface.

emulate -LR zsh

# --------------------------------------------------
# Paths and test environment
# --------------------------------------------------

TEST_DIR="${0:A:h:h}"
PROJECT_ROOT="${TEST_DIR:h:h}"

HELPERS_PATH="$TEST_DIR/test-helpers.zsh"
SCRIPT_PATH="$PROJECT_ROOT/Zsh/MarkitdownRecursive.zsh"

source "$HELPERS_PATH"

TEMP_DIR="$(mktemp -d)" || {
    print -u2 -- "Error: Could not create temporary test directory."
    exit 2
}

cleanup() {
    rm -rf -- "$TEMP_DIR"
}

trap cleanup EXIT

typeset -i CASE_NUMBER=0


# --------------------------------------------------
# CLI test helper
# --------------------------------------------------

# Runs the script once, captures its output and exit code,
# and verifies both against the expected results.
run_cli_case() {
    local description="$1"
    local expected_exit_code="$2"
    local expected_output="$3"

    shift 3

    (( ++CASE_NUMBER ))

    local output_file="$TEMP_DIR/cli-case-${CASE_NUMBER}.log"
    local actual_exit_code

    zsh -f "$SCRIPT_PATH" "$@" > "$output_file" 2>&1
    actual_exit_code=$?

    # Verify the process exit code.
    assert_equal \
        "$expected_exit_code" \
        "$actual_exit_code" \
        "$description: exit code"

    # Verify output only when an expected string was provided.
    if [[ -n "$expected_output" ]]; then
        local command_output
        command_output="$(< "$output_file")"

        assert_contains \
            "$expected_output" \
            "$command_output" \
            "$description: output"
    fi
}


# --------------------------------------------------
# Help options
# --------------------------------------------------

run_cli_case \
    "--help displays the usage information" \
    0 \
    "Usage:" \
    --help

run_cli_case \
    "-h displays the usage information" \
    0 \
    "Usage:" \
    -h


# --------------------------------------------------
# Invalid argument count
# --------------------------------------------------

run_cli_case \
    "Multiple arguments are rejected" \
    2 \
    "" \
    first second


# --------------------------------------------------
# Invalid source paths
# --------------------------------------------------

run_cli_case \
    "A nonexistent source directory is rejected" \
    2 \
    "" \
    "$TEMP_DIR/nonexistent-directory"


# A regular file must not be accepted as a source directory.
: > "$TEMP_DIR/source-file"

run_cli_case \
    "A regular file is rejected as a source directory" \
    2 \
    "" \
    "$TEMP_DIR/source-file"


# --------------------------------------------------
# Report results
# --------------------------------------------------

test_summary