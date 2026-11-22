
#!/usr/bin/env zsh

# Integration tests for temporary file and directory cleanup.

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

TEST_TMP_DIR="$TEMP_DIR/system-tmp"

mkdir -p "$TEST_TMP_DIR" || {
    print -u2 -- "Error: Could not create temporary system temp directory."
    exit 2
}

cleanup() {
    rm -rf -- "$TEMP_DIR"
}

trap cleanup EXIT

typeset -a temp_entries
typeset -a conversion_temp_entries


# --------------------------------------------------
# Mock MarkItDown dependency
# --------------------------------------------------

MOCK_BIN="$TEMP_DIR/bin"

mkdir -p "$MOCK_BIN" || {
    print -u2 -- "Error: Could not create mock directory."
    exit 2
}

cat > "$MOCK_BIN/markitdown" <<'MOCK'
#!/usr/bin/env sh

# Validate the arguments received from the main script.
if [ "$#" -ne 3 ] || [ "$2" != "-o" ]; then
    printf 'Unexpected MarkItDown arguments.\n' >&2
    exit 64
fi

# Simulate successful conversion, conversion failure and interruption.
case "${1##*/}" in
    fail.pdf)
        exit 42
        ;;
    terminate.pdf)
        # Send SIGTERM to the parent MarkitDownRecursive process.
        kill -TERM "$PPID"
        exit 0
        ;;
    *)
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
# Test 1: Cleanup after successful conversion
# --------------------------------------------------

SUCCESS_SOURCE_DIR="$TEMP_DIR/success"
SUCCESS_OUTPUT_DIR="$SUCCESS_SOURCE_DIR/${SUCCESS_SOURCE_DIR:t} Markdown"

mkdir -p "$SUCCESS_SOURCE_DIR" || exit 2

printf 'Successful document\n' > "$SUCCESS_SOURCE_DIR/document.pdf"

output="$(
    TMPDIR="$TEST_TMP_DIR" "$ZSH_BIN" -f "$SCRIPT_PATH" \
        "$SUCCESS_SOURCE_DIR" 2>&1
)"
actual_exit_code=$?

assert_equal \
    0 \
    "$actual_exit_code" \
    "Successful conversion exits with code 0"

assert_file_exists \
    "$SUCCESS_OUTPUT_DIR/document.md" \
    "Successful conversion publishes the final Markdown file"

temp_entries=(
    "$TEST_TMP_DIR"/markitdown-recursive.*(N)
    "$TEST_TMP_DIR"/markitdown-recursive-sorted.*(N)
)

assert_equal \
    0 \
    "${#temp_entries[@]}" \
    "Temporary manifests are removed after successful conversion"

conversion_temp_entries=(
    "$SUCCESS_OUTPUT_DIR"/.markitdown.*(N)
)

assert_equal \
    0 \
    "${#conversion_temp_entries[@]}" \
    "Temporary conversion directories are removed after success"


# --------------------------------------------------
# Test 2: Cleanup after conversion failure
# --------------------------------------------------

FAIL_SOURCE_DIR="$TEMP_DIR/failure"
FAIL_OUTPUT_DIR="$FAIL_SOURCE_DIR/${FAIL_SOURCE_DIR:t} Markdown"

mkdir -p "$FAIL_SOURCE_DIR" || exit 2

printf 'Failing document\n' > "$FAIL_SOURCE_DIR/fail.pdf"

output="$(
    TMPDIR="$TEST_TMP_DIR" "$ZSH_BIN" -f "$SCRIPT_PATH" \
        "$FAIL_SOURCE_DIR" 2>&1
)"
actual_exit_code=$?

assert_equal \
    1 \
    "$actual_exit_code" \
    "Failed conversion exits with code 1"

assert_file_not_exists \
    "$FAIL_OUTPUT_DIR/fail.md" \
    "Failed conversion does not publish a final Markdown file"

temp_entries=(
    "$TEST_TMP_DIR"/markitdown-recursive.*(N)
    "$TEST_TMP_DIR"/markitdown-recursive-sorted.*(N)
)

assert_equal \
    0 \
    "${#temp_entries[@]}" \
    "Temporary manifests are removed after conversion failure"

conversion_temp_entries=(
    "$FAIL_OUTPUT_DIR"/.markitdown.*(N)
)

assert_equal \
    0 \
    "${#conversion_temp_entries[@]}" \
    "Temporary conversion directories are removed after failure"


# --------------------------------------------------
# Test 3: Cleanup after SIGTERM interruption
# --------------------------------------------------

TERM_SOURCE_DIR="$TEMP_DIR/interruption"
TERM_OUTPUT_DIR="$TERM_SOURCE_DIR/${TERM_SOURCE_DIR:t} Markdown"

mkdir -p "$TERM_SOURCE_DIR" || exit 2

printf 'Document that triggers interruption\n' \
    > "$TERM_SOURCE_DIR/terminate.pdf"

output="$(
    TMPDIR="$TEST_TMP_DIR" "$ZSH_BIN" -f "$SCRIPT_PATH" \
        "$TERM_SOURCE_DIR" 2>&1
)"
actual_exit_code=$?

assert_equal \
    143 \
    "$actual_exit_code" \
    "SIGTERM interruption exits with code 143"

assert_file_not_exists \
    "$TERM_OUTPUT_DIR/terminate.md" \
    "An interrupted conversion does not publish an incomplete result"

temp_entries=(
    "$TEST_TMP_DIR"/markitdown-recursive.*(N)
    "$TEST_TMP_DIR"/markitdown-recursive-sorted.*(N)
)

assert_equal \
    0 \
    "${#temp_entries[@]}" \
    "Temporary manifests are removed after SIGTERM"

conversion_temp_entries=(
    "$TERM_OUTPUT_DIR"/.markitdown.*(N)
)

assert_equal \
    0 \
    "${#conversion_temp_entries[@]}" \
    "Temporary conversion directories are removed after SIGTERM"


# --------------------------------------------------
# Report results
# --------------------------------------------------

test_summary
