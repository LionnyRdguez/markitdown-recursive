
#!/usr/bin/env zsh

# Integration tests for hidden files, hidden directories and special files.

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

# Record the source file passed for conversion.
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
# Create source files and directories
# --------------------------------------------------

SOURCE_DIR="$TEMP_DIR/source files"
OUTPUT_DIR="$SOURCE_DIR/${SOURCE_DIR:t} Markdown"

mkdir -p \
    "$SOURCE_DIR/.hidden folder" \
    "$SOURCE_DIR/visible folder" || {
        print -u2 -- "Error: Could not create source directories."
        exit 2
    }

# Visible regular files must be processed.
printf 'Visible document content\n' > "$SOURCE_DIR/visible.pdf"

# Hidden files must not be processed.
printf 'Hidden document content\n' > "$SOURCE_DIR/.hidden-file.pdf"
printf 'Hidden nested document content\n' > "$SOURCE_DIR/.hidden folder/secret.pdf"

# A regular file inside a visible directory must still be processed.
printf 'Nested visible document content\n' > "$SOURCE_DIR/visible folder/nested.pdf"

# Create a FIFO special file. It must be skipped without being opened.
mkfifo "$SOURCE_DIR/pipe" || {
    print -u2 -- "Error: Could not create FIFO test file."
    exit 2
}


# --------------------------------------------------
# Execute the script
# --------------------------------------------------

output="$(zsh -f "$SCRIPT_PATH" "$SOURCE_DIR" 2>&1)"
actual_exit_code=$?

assert_equal \
    0 \
    "$actual_exit_code" \
    "The script processes the source without errors"

if (( actual_exit_code != 0 )); then
    print -u2 -- "Script output:"
    print -u2 -r -- "$output"
fi


# --------------------------------------------------
# Visible files must be processed
# --------------------------------------------------

assert_file_exists \
    "$OUTPUT_DIR/visible.md" \
    "A visible regular file is converted"

assert_file_exists \
    "$OUTPUT_DIR/visible folder Markdown/nested.md" \
    "A visible file inside a directory is converted"


# --------------------------------------------------
# Hidden files and directories must be excluded
# --------------------------------------------------

assert_file_not_exists \
    "$OUTPUT_DIR/.hidden-file.md" \
    "A hidden file is not converted"

assert_directory_not_exists \
    "$OUTPUT_DIR/.hidden folder Markdown" \
    "A hidden directory is not replicated"

assert_file_not_exists \
    "$OUTPUT_DIR/.hidden folder Markdown/secret.md" \
    "Files inside hidden directories are not converted"


# --------------------------------------------------
# Special files must be skipped
# --------------------------------------------------

assert_file_not_exists \
    "$OUTPUT_DIR/pipe.md" \
    "A FIFO special file is not converted"

special_count="$(
    print -r -- "$output" |
        sed -n 's/^Skipped special files:[[:space:]]*//p'
)"

assert_equal \
    1 \
    "$special_count" \
    "Exactly one special file is reported as skipped"


# --------------------------------------------------
# Verify MarkItDown invocation
# --------------------------------------------------

expected_calls="$(
    printf '%s\n%s' \
        "$SOURCE_DIR/visible folder/nested.pdf" \
        "$SOURCE_DIR/visible.pdf"
)"

actual_calls="$(< "$MOCK_LOG")"

assert_equal \
    "$expected_calls" \
    "$actual_calls" \
    "Only visible regular files are sent to MarkItDown"


# --------------------------------------------------
# Report results
# --------------------------------------------------

test_summary
