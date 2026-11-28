
#!/usr/bin/env zsh

# Integration tests for symbolic link handling.

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
# Create source and external targets
# --------------------------------------------------

SOURCE_DIR="$TEMP_DIR/source files"
OUTPUT_DIR="$SOURCE_DIR/${SOURCE_DIR:t} Markdown"

EXTERNAL_DIR="$TEMP_DIR/external directory"

mkdir -p "$SOURCE_DIR" "$EXTERNAL_DIR/nested folder" || {
    print -u2 -- "Error: Could not create test directories."
    exit 2
}

# A regular file inside the source must be processed.
printf 'Visible source content\n' > "$SOURCE_DIR/visible.pdf"

# External targets must never be processed through their symbolic links.
printf 'External file content\n' > "$EXTERNAL_DIR/linked.pdf"
printf 'External nested content\n' > "$EXTERNAL_DIR/nested folder/secret.pdf"

# Create a symbolic link to an external regular file.
ln -s \
    "$EXTERNAL_DIR/linked.pdf" \
    "$SOURCE_DIR/linked-file.pdf" || {
        print -u2 -- "Error: Could not create file symbolic link."
        exit 2
    }

# Create a symbolic link to an external directory.
ln -s \
    "$EXTERNAL_DIR" \
    "$SOURCE_DIR/linked-directory" || {
        print -u2 -- "Error: Could not create directory symbolic link."
        exit 2
    }

# Create a broken symbolic link.
ln -s \
    "$TEMP_DIR/nonexistent-target.pdf" \
    "$SOURCE_DIR/broken-link.pdf" || {
        print -u2 -- "Error: Could not create broken symbolic link."
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
    "The script processes the source successfully"

if (( actual_exit_code != 0 )); then
    print -u2 -- "Script output:"
    print -u2 -r -- "$output"
fi


# --------------------------------------------------
# Regular files must still be processed
# --------------------------------------------------

assert_file_exists \
    "$OUTPUT_DIR/visible.md" \
    "A regular source file is converted"

assert_contains \
    "Mock conversion output for: visible.pdf" \
    "$(< "$OUTPUT_DIR/visible.md")" \
    "The regular file contains the expected converted output"


# --------------------------------------------------
# Symbolic links to files must be skipped
# --------------------------------------------------

assert_file_not_exists \
    "$OUTPUT_DIR/linked-file.md" \
    "A symbolic link to a file is not converted"


# --------------------------------------------------
# Symbolic links to directories must be skipped
# --------------------------------------------------

assert_directory_not_exists \
    "$OUTPUT_DIR/linked-directory Markdown" \
    "A symbolic link to a directory is not replicated"

assert_file_not_exists \
    "$OUTPUT_DIR/linked-directory Markdown/nested folder Markdown/secret.md" \
    "Files inside a linked directory are not processed"


# --------------------------------------------------
# Broken symbolic links must be skipped
# --------------------------------------------------

assert_file_not_exists \
    "$OUTPUT_DIR/broken-link.md" \
    "A broken symbolic link is not converted"


# --------------------------------------------------
# Verify symbolic link reporting
# --------------------------------------------------

symlink_messages="$(
    print -r -- "$output" |
        grep -F -c 'Skipped (symbolic link):'
)"

assert_equal \
    3 \
    "$symlink_messages" \
    "All three symbolic links are reported as skipped"

reported_symlinks="$(
    print -r -- "$output" |
        sed -n 's/^Skipped symlinks:[[:space:]]*//p'
)"

assert_equal \
    3 \
    "$reported_symlinks" \
    "The final summary reports three skipped symbolic links"


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
    "MarkItDown is invoked only for the regular source file"

actual_calls="$(< "$MOCK_LOG")"

assert_equal \
    "$SOURCE_DIR/visible.pdf" \
    "$actual_calls" \
    "No symbolic link target is sent to MarkItDown"


# --------------------------------------------------
# Report results
# --------------------------------------------------

test_summary
