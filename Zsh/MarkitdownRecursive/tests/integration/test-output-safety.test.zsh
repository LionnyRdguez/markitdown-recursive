
#!/usr/bin/env zsh

# Integration tests for output directory safety.

emulate -LR zsh


# --------------------------------------------------
# Paths and test environment
# --------------------------------------------------

TEST_DIR="${0:A:h:h}"
PROJECT_ROOT="${TEST_DIR:h:h}"

source "$TEST_DIR/test-helpers.zsh"

SCRIPT_PATH="$PROJECT_ROOT/Zsh/MarkitdownRecursive.zsh"

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

# Generate deterministic Markdown output.
printf 'Mock conversion output for: %s\n' "${1##*/}" > "$3"
MOCK

chmod +x "$MOCK_BIN/markitdown" || {
    print -u2 -- "Error: Could not prepare mock executable."
    exit 2
}

export PATH="$MOCK_BIN:$PATH"


# --------------------------------------------------
# Test 1: Output root is a symbolic link
# --------------------------------------------------

ROOT_SOURCE="$TEMP_DIR/root link source"
ROOT_EXTERNAL="$TEMP_DIR/root external destination"
ROOT_OUTPUT="$ROOT_SOURCE/${ROOT_SOURCE:t} Markdown"

mkdir -p "$ROOT_SOURCE" "$ROOT_EXTERNAL" || exit 2

printf 'Source document\n' > "$ROOT_SOURCE/document.pdf"
printf 'External sentinel\n' > "$ROOT_EXTERNAL/sentinel.txt"
printf 'External sentinel\n' > "$TEMP_DIR/expected-root-sentinel"

ln -s "$ROOT_EXTERNAL" "$ROOT_OUTPUT" || {
    print -u2 -- "Error: Could not create output root symbolic link."
    exit 2
}

output="$(zsh -f "$SCRIPT_PATH" "$ROOT_SOURCE" 2>&1)"
actual_exit_code=$?

assert_equal \
    2 \
    "$actual_exit_code" \
    "A symbolic link used as the output root is rejected"

assert_contains \
    "output folder is a symbolic link" \
    "$output" \
    "The output root symbolic link produces a clear error"

assert_exit_code 0 cmp -s \
    "$TEMP_DIR/expected-root-sentinel" \
    "$ROOT_EXTERNAL/sentinel.txt"

assert_file_not_exists \
    "$ROOT_EXTERNAL/document.md" \
    "The script does not write converted files into the external target"

assert_exit_code 0 test -L "$ROOT_OUTPUT"


# --------------------------------------------------
# Test 2: Nested output directory is a symbolic link
# --------------------------------------------------

NESTED_SOURCE="$TEMP_DIR/nested link source"
NESTED_OUTPUT="$NESTED_SOURCE/${NESTED_SOURCE:t} Markdown"

NESTED_EXTERNAL="$TEMP_DIR/nested external destination"
NESTED_LINK="$NESTED_OUTPUT/nested folder Markdown"

mkdir -p \
    "$NESTED_SOURCE/nested folder" \
    "$NESTED_OUTPUT" \
    "$NESTED_EXTERNAL" || exit 2

# A normal top-level file should still be processed.
printf 'Normal document\n' > "$NESTED_SOURCE/normal.pdf"

# This file would normally be placed inside the nested output directory.
printf 'Nested document\n' > "$NESTED_SOURCE/nested folder/secret.pdf"

printf 'External sentinel\n' > "$NESTED_EXTERNAL/sentinel.txt"
printf 'External sentinel\n' > "$TEMP_DIR/expected-nested-sentinel"

# Replace the expected nested output directory with a symbolic link.
ln -s "$NESTED_EXTERNAL" "$NESTED_LINK" || {
    print -u2 -- "Error: Could not create nested output symbolic link."
    exit 2
}

output="$(zsh -f "$SCRIPT_PATH" "$NESTED_SOURCE" 2>&1)"
actual_exit_code=$?

assert_equal \
    1 \
    "$actual_exit_code" \
    "A nested output symbolic link causes a processing error"

assert_file_exists \
    "$NESTED_OUTPUT/normal.md" \
    "Files outside the blocked directory are still processed"

assert_exit_code 0 cmp -s \
    "$TEMP_DIR/expected-nested-sentinel" \
    "$NESTED_EXTERNAL/sentinel.txt"

assert_file_not_exists \
    "$NESTED_EXTERNAL/secret.md" \
    "The script does not write into the external nested target"

assert_exit_code 0 test -L "$NESTED_LINK"

directory_errors="$(
    print -r -- "$output" |
        sed -n 's/^Folder creation errors:[[:space:]]*\([0-9][0-9]*\)$/\1/p'
)"

assert_equal \
    1 \
    "$directory_errors" \
    "The final summary reports one directory creation error"

failed_count="$(
    print -r -- "$output" |
        sed -n 's/^Failed conversions:[[:space:]]*\([0-9][0-9]*\)$/\1/p'
)"

assert_equal \
    1 \
    "$failed_count" \
    "The file blocked by the symbolic link is counted as a failure"


# --------------------------------------------------
# Report results
# --------------------------------------------------

test_summary
