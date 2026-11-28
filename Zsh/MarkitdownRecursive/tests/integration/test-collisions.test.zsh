
#!/usr/bin/env zsh

# Integration tests for filename collisions and overwrite protection.

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

# Record each conversion request.
printf '%s\n' "$1" >> "$MOCK_LOG" || exit 74

# Generate deterministic Markdown output.
printf 'Mock conversion output for: %s\n' "${1##*/}" > "$3"
MOCK

chmod +x "$MOCK_BIN/markitdown" || {
    print -u2 -- "Error: Could not prepare mock executable."
    exit 2
}

export PATH="$MOCK_BIN:$PATH"


# --------------------------------------------------
# Create source files and destination fixtures
# --------------------------------------------------

SOURCE_DIR="$TEMP_DIR/source files"
OUTPUT_DIR="$SOURCE_DIR/${SOURCE_DIR:t} Markdown"

mkdir -p "$SOURCE_DIR" "$OUTPUT_DIR" || {
    print -u2 -- "Error: Could not create test directories."
    exit 2
}

# Two source files that produce the same destination filename.
printf 'DOCX source content\n' > "$SOURCE_DIR/duplicate.docx"
printf 'PDF source content\n' > "$SOURCE_DIR/duplicate.pdf"

# This source file targets a destination that already exists.
printf 'New source content\n' > "$SOURCE_DIR/existing.pdf"

# Pre-existing destination that must never be overwritten.
printf 'Original destination content\n' > "$OUTPUT_DIR/existing.md"

# Keep an independent reference for byte-by-byte comparison.
printf 'Original destination content\n' > "$TEMP_DIR/expected-existing.md"


# --------------------------------------------------
# Execute the script
# --------------------------------------------------

output="$(zsh -f "$SCRIPT_PATH" "$SOURCE_DIR" 2>&1)"
actual_exit_code=$?

assert_equal \
    0 \
    "$actual_exit_code" \
    "The script handles collisions and existing destinations successfully"

if (( actual_exit_code != 0 )); then
    print -u2 -- "Script output:"
    print -u2 -r -- "$output"
fi


# --------------------------------------------------
# Source filename collision
# --------------------------------------------------

assert_file_exists \
    "$OUTPUT_DIR/duplicate.md" \
    "The first file in deterministic order creates the destination"

assert_contains \
    "Mock conversion output for: duplicate.docx" \
    "$(< "$OUTPUT_DIR/duplicate.md")" \
    "The destination contains the output from duplicate.docx"

assert_not_contains \
    "duplicate.pdf" \
    "$(< "$OUTPUT_DIR/duplicate.md")" \
    "The colliding PDF does not replace the first result"

assert_file_exists \
    "$SOURCE_DIR/duplicate.docx" \
    "The original DOCX file remains intact"

assert_file_exists \
    "$SOURCE_DIR/duplicate.pdf" \
    "The original PDF file remains intact"


# --------------------------------------------------
# Pre-existing destination protection
# --------------------------------------------------

assert_file_exists \
    "$OUTPUT_DIR/existing.md" \
    "The pre-existing destination remains present"

assert_exit_code 0 cmp -s \
    "$TEMP_DIR/expected-existing.md" \
    "$OUTPUT_DIR/existing.md"

# The original destination must not contain the mock conversion result.
assert_not_contains \
    "Mock conversion output" \
    "$(< "$OUTPUT_DIR/existing.md")" \
    "The pre-existing destination was not overwritten"


# --------------------------------------------------
# Verify skip counters
# --------------------------------------------------

existing_count="$(
    print -r -- "$output" |
        sed -n 's/^Skipped (destination exists):[[:space:]]*//p'
)"

assert_equal \
    1 \
    "$existing_count" \
    "Exactly one existing destination is skipped"


collision_count="$(
    print -r -- "$output" |
        sed -n 's/^Skipped (name collision):[[:space:]]*\([0-9][0-9]*\)$/\1/p'
)"

assert_equal \
    1 \
    "$collision_count" \
    "Exactly one source filename collision is skipped"


# --------------------------------------------------
# Verify MarkItDown invocation
# --------------------------------------------------

typeset -i MOCK_CALLS=0

while IFS= read -r mock_call; do
    (( ++MOCK_CALLS ))
done < "$MOCK_LOG"

assert_equal \
    1 \
    "$MOCK_CALLS" \
    "MarkItDown is invoked only for the winning collision candidate"

actual_calls="$(< "$MOCK_LOG")"

assert_equal \
    "$SOURCE_DIR/duplicate.docx" \
    "$actual_calls" \
    "The deterministic first candidate is the only one converted"


# --------------------------------------------------
# Report results
# --------------------------------------------------

test_summary
