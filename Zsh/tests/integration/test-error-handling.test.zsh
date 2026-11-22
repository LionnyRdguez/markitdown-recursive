
#!/usr/bin/env zsh

# Integration tests for error handling and partial processing.

emulate -LR zsh


# --------------------------------------------------
# Paths and test environment
# --------------------------------------------------

TEST_DIR="${0:A:h:h}"
PROJECT_ROOT="${TEST_DIR:h:h}"

source "$TEST_DIR/test-helpers.zsh"

SCRIPT_PATH="$PROJECT_ROOT/Zsh/MarkitdownRecursive.zsh"
ZSH_BIN="$(command -v zsh)"

TEMP_DIR="$(mktemp -d)" || {
    print -u2 -- "Error: Could not create temporary test directory."
    exit 2
}

cleanup() {
    rm -rf -- "$TEMP_DIR"
}

trap cleanup EXIT


# --------------------------------------------------
# Mock MarkItDown dependency
# --------------------------------------------------

MOCK_BIN="$TEMP_DIR/bin"
MOCK_LOG="$TEMP_DIR/markitdown.log"

mkdir -p "$MOCK_BIN" || {
    print -u2 -- "Error: Could not create mock directory."
    exit 2
}

: > "$MOCK_LOG"
export MOCK_LOG

cat > "$MOCK_BIN/markitdown" <<'MOCK'
#!/usr/bin/env sh

# Validate the arguments received from the main script.
if [ "$#" -ne 3 ] || [ "$2" != "-o" ]; then
    printf 'Unexpected MarkItDown arguments.\n' >&2
    exit 64
fi

# Record every conversion attempt.
printf '%s\n' "$1" >> "$MOCK_LOG" || exit 74

# Simulate different conversion outcomes.
case "${1##*/}" in
    *fail.pdf)
        # Simulate a failed conversion.
        exit 42
        ;;
    no-output.pdf)
        # Simulate a successful command that produces no output file.
        exit 0
        ;;
    *)
        # Generate deterministic Markdown output.
        printf 'Mock conversion output for: %s\n' "${1##*/}" > "$3"
        ;;
esac
MOCK

chmod +x "$MOCK_BIN/markitdown" || {
    print -u2 -- "Error: Could not prepare mock executable."
    exit 2
}

export PATH="$MOCK_BIN:$PATH"


# --------------------------------------------------
# Test 1: Partial conversion failure
# --------------------------------------------------

PARTIAL_SOURCE_DIR="$TEMP_DIR/partial processing"
PARTIAL_OUTPUT_DIR="$PARTIAL_SOURCE_DIR/${PARTIAL_SOURCE_DIR:t} Markdown"

mkdir -p "$PARTIAL_SOURCE_DIR" || exit 2

printf 'Failing document\n' > "$PARTIAL_SOURCE_DIR/01-fail.pdf"
printf 'Successful document\n' > "$PARTIAL_SOURCE_DIR/02-success.pdf"

output="$(zsh -f "$SCRIPT_PATH" "$PARTIAL_SOURCE_DIR" 2>&1)"
actual_exit_code=$?

assert_equal \
    1 \
    "$actual_exit_code" \
    "A failed conversion produces exit code 1"

assert_file_exists \
    "$PARTIAL_OUTPUT_DIR/02-success.md" \
    "Processing continues after another file fails"

assert_file_not_exists \
    "$PARTIAL_OUTPUT_DIR/01-fail.md" \
    "A failed conversion does not publish an output file"

assert_contains \
    "Mock conversion output for: 02-success.pdf" \
    "$(< "$PARTIAL_OUTPUT_DIR/02-success.md")" \
    "The successful file contains the expected output"

failed_count="$(
    print -r -- "$output" |
        sed -n 's/^Failed conversions:[[:space:]]*\([0-9][0-9]*\)$/\1/p'
)"

assert_equal \
    1 \
    "$failed_count" \
    "The final summary reports one failed conversion"

typeset -a temp_entries
temp_entries=("$PARTIAL_OUTPUT_DIR"/.markitdown.*(N))

assert_equal \
    0 \
    "${#temp_entries[@]}" \
    "Temporary conversion directories are removed after failures"


# --------------------------------------------------
# Test 2: MarkItDown produces no output file
# --------------------------------------------------

NO_OUTPUT_SOURCE_DIR="$TEMP_DIR/missing output"
NO_OUTPUT_DIR="$NO_OUTPUT_SOURCE_DIR/${NO_OUTPUT_SOURCE_DIR:t} Markdown"

mkdir -p "$NO_OUTPUT_SOURCE_DIR" || exit 2

printf 'Document without generated output\n' \
    > "$NO_OUTPUT_SOURCE_DIR/no-output.pdf"

output="$(zsh -f "$SCRIPT_PATH" "$NO_OUTPUT_SOURCE_DIR" 2>&1)"
actual_exit_code=$?

assert_equal \
    1 \
    "$actual_exit_code" \
    "Missing conversion output produces exit code 1"

assert_file_not_exists \
    "$NO_OUTPUT_DIR/no-output.md" \
    "A missing temporary output is not published"

failed_count="$(
    print -r -- "$output" |
        sed -n 's/^Failed conversions:[[:space:]]*\([0-9][0-9]*\)$/\1/p'
)"

assert_equal \
    1 \
    "$failed_count" \
    "Missing conversion output is counted as a failure"

temp_entries=("$NO_OUTPUT_DIR"/.markitdown.*(N))

assert_equal \
    0 \
    "${#temp_entries[@]}" \
    "Temporary directories are removed when output is missing"


# --------------------------------------------------
# Test 3: Invalid output path
# --------------------------------------------------

BLOCKED_SOURCE_DIR="$TEMP_DIR/blocked source"
BLOCKED_OUTPUT_PATH="$BLOCKED_SOURCE_DIR/${BLOCKED_SOURCE_DIR:t} Markdown"

mkdir -p "$BLOCKED_SOURCE_DIR" || exit 2

printf 'Source document\n' > "$BLOCKED_SOURCE_DIR/document.pdf"

# A regular file occupies the path where the output directory must be created.
printf 'Do not replace this file\n' > "$BLOCKED_OUTPUT_PATH"

printf 'Do not replace this file\n' > "$TEMP_DIR/expected-blocked-output"

: > "$MOCK_LOG"

output="$(zsh -f "$SCRIPT_PATH" "$BLOCKED_SOURCE_DIR" 2>&1)"
actual_exit_code=$?

assert_equal \
    2 \
    "$actual_exit_code" \
    "An invalid output path prevents execution"

assert_contains \
    "output path exists, but it is not a folder" \
    "$output" \
    "The invalid output path produces a clear error"

assert_exit_code 0 cmp -s \
    "$TEMP_DIR/expected-blocked-output" \
    "$BLOCKED_OUTPUT_PATH"

assert_equal \
    "" \
    "$(< "$MOCK_LOG")" \
    "MarkItDown is not invoked when the output path is invalid"


# --------------------------------------------------
# Test 4: Missing MarkItDown dependency
# --------------------------------------------------

EMPTY_BIN="$TEMP_DIR/empty-bin"
MISSING_DEP_SOURCE_DIR="$TEMP_DIR/missing dependency"

mkdir -p "$EMPTY_BIN" "$MISSING_DEP_SOURCE_DIR" || exit 2

printf 'Source document\n' > "$MISSING_DEP_SOURCE_DIR/document.pdf"

output="$(
    PATH="$EMPTY_BIN" "$ZSH_BIN" -f "$SCRIPT_PATH" \
        "$MISSING_DEP_SOURCE_DIR" 2>&1
)"
actual_exit_code=$?

assert_equal \
    2 \
    "$actual_exit_code" \
    "A missing MarkItDown dependency produces exit code 2"

assert_contains \
    "'markitdown' was not found in the PATH" \
    "$output" \
    "The missing MarkItDown dependency produces a clear error"

assert_directory_not_exists \
    "$MISSING_DEP_SOURCE_DIR/${MISSING_DEP_SOURCE_DIR:t} Markdown" \
    "The output directory is not created when MarkItDown is missing"


# --------------------------------------------------
# Test 5: Missing system dependency
# --------------------------------------------------

CHECK_BIN="$TEMP_DIR/check-bin"
MISSING_FIND_SOURCE_DIR="$TEMP_DIR/missing find"

mkdir -p "$CHECK_BIN" "$MISSING_FIND_SOURCE_DIR" || exit 2

# Provide MarkItDown but deliberately omit find and other system tools.
cat > "$CHECK_BIN/markitdown" <<'MOCK'
#!/bin/sh
exit 0
MOCK

chmod +x "$CHECK_BIN/markitdown" || exit 2

printf 'Source document\n' > "$MISSING_FIND_SOURCE_DIR/document.pdf"

output="$(
    PATH="$CHECK_BIN" "$ZSH_BIN" -f "$SCRIPT_PATH" \
        "$MISSING_FIND_SOURCE_DIR" 2>&1
)"
actual_exit_code=$?

assert_equal \
    2 \
    "$actual_exit_code" \
    "A missing system dependency produces exit code 2"

assert_contains \
    "required dependency not found: find" \
    "$output" \
    "The missing system dependency is identified correctly"


# --------------------------------------------------
# Report results
# --------------------------------------------------

test_summary
