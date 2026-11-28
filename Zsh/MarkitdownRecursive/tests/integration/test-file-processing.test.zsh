
#!/usr/bin/env zsh

# Integration tests for file conversion and Markdown copying.

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
# Create source files
# --------------------------------------------------

SOURCE_DIR="$TEMP_DIR/source files"
OUTPUT_DIR="$SOURCE_DIR/${SOURCE_DIR:t} Markdown"

mkdir -p "$SOURCE_DIR/nested folder" || {
    print -u2 -- "Error: Could not create source directories."
    exit 2
}

# Files that must be converted.
printf 'PDF source content\n' > "$SOURCE_DIR/report.pdf"
printf 'Spreadsheet source content\n' > "$SOURCE_DIR/data.v2.xlsx"
printf 'Extensionless source content\n' > "$SOURCE_DIR/README"
printf 'Nested document content\n' > "$SOURCE_DIR/nested folder/meeting.docx"

# Markdown files that must be copied without conversion.
printf 'Original Markdown content\n' > "$SOURCE_DIR/notes.md"
printf 'Uppercase Markdown content\n' > "$SOURCE_DIR/UPPER.MD"


# --------------------------------------------------
# Execute the script
# --------------------------------------------------

output="$(zsh -f "$SCRIPT_PATH" "$SOURCE_DIR" 2>&1)"
actual_exit_code=$?

assert_equal \
    0 \
    "$actual_exit_code" \
    "The script processes all supported test files successfully"

if (( actual_exit_code != 0 )); then
    print -u2 -- "Script output:"
    print -u2 -r -- "$output"
fi


# --------------------------------------------------
# Converted file existence
# --------------------------------------------------

assert_file_exists \
    "$OUTPUT_DIR/report.md" \
    "A PDF file is converted to Markdown"

assert_file_exists \
    "$OUTPUT_DIR/data.v2.md" \
    "Only the final extension is removed"

assert_file_not_exists \
    "$OUTPUT_DIR/data.md" \
    "Intermediate filename extensions are preserved"

assert_file_exists \
    "$OUTPUT_DIR/README.md" \
    "A file without an extension receives .md"

assert_file_exists \
    "$OUTPUT_DIR/nested folder Markdown/meeting.md" \
    "A nested document is converted in its corresponding directory"


# --------------------------------------------------
# Converted file content
# --------------------------------------------------

assert_contains \
    "Mock conversion output for: report.pdf" \
    "$(< "$OUTPUT_DIR/report.md")" \
    "Converted output contains the expected PDF result"

assert_contains \
    "Mock conversion output for: data.v2.xlsx" \
    "$(< "$OUTPUT_DIR/data.v2.md")" \
    "Converted output contains the expected spreadsheet result"

assert_contains \
    "Mock conversion output for: README" \
    "$(< "$OUTPUT_DIR/README.md")" \
    "Converted output contains the expected extensionless file result"

assert_contains \
    "Mock conversion output for: meeting.docx" \
    "$(< "$OUTPUT_DIR/nested folder Markdown/meeting.md")" \
    "Nested converted output contains the expected content"


# --------------------------------------------------
# Existing Markdown copying
# --------------------------------------------------

assert_file_exists \
    "$OUTPUT_DIR/notes.md" \
    "An existing .md file is copied"

assert_exit_code 0 cmp -s \
    "$SOURCE_DIR/notes.md" \
    "$OUTPUT_DIR/notes.md"

assert_file_exists \
    "$OUTPUT_DIR/UPPER.md" \
    "An uppercase .MD extension is normalized to .md"

assert_exit_code 0 cmp -s \
    "$SOURCE_DIR/UPPER.MD" \
    "$OUTPUT_DIR/UPPER.md"


# --------------------------------------------------
# Verify MarkItDown invocation
# --------------------------------------------------

typeset -i MOCK_CALLS=0

while IFS= read -r mock_call; do
    (( ++MOCK_CALLS ))
done < "$MOCK_LOG"

assert_equal \
    4 \
    "$MOCK_CALLS" \
    "MarkItDown is invoked exactly once for each non-Markdown file"

mock_log_content="$(< "$MOCK_LOG")"

assert_not_contains \
    "$SOURCE_DIR/notes.md" \
    "$mock_log_content" \
    "Existing .md files are not sent to MarkItDown"

assert_not_contains \
    "$SOURCE_DIR/UPPER.MD" \
    "$mock_log_content" \
    "Uppercase .MD files are not sent to MarkItDown"


# --------------------------------------------------
# Report results
# --------------------------------------------------

test_summary
