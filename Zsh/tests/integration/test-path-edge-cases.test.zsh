
#!/usr/bin/env zsh

# Integration tests for unusual paths and default source directory handling.

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

# Validate arguments received from the main script.
if [ "$#" -ne 3 ] || [ "$2" != "-o" ]; then
    printf 'Unexpected MarkItDown arguments.\n' >&2
    exit 64
fi

# Record one conversion without logging the source path.
# This keeps the log safe even when filenames contain newlines.
printf 'conversion\n' >> "$MOCK_LOG" || exit 74

# Generate deterministic output.
printf 'Mock converted content\n' > "$3"
MOCK

chmod +x "$MOCK_BIN/markitdown" || {
    print -u2 -- "Error: Could not prepare mock executable."
    exit 2
}

export PATH="$MOCK_BIN:$PATH"


# --------------------------------------------------
# Test 1: Unusual filenames and directory names
# --------------------------------------------------

SOURCE_DIR="$TEMP_DIR/unusual paths"
OUTPUT_DIR="$SOURCE_DIR/${SOURCE_DIR:t} Markdown"

NESTED_NAME=$'nested\nfolder [special] $name'
NESTED_DIR="$SOURCE_DIR/$NESTED_NAME"

mkdir -p "$NESTED_DIR" || {
    print -u2 -- "Error: Could not create unusual source directories."
    exit 2
}

# Create filenames containing unusual characters.
NEWLINE_FILE=$'line\nbreak.pdf'
TAB_FILE=$'tab\tname.pdf'
DASH_FILE="-leading-dash.pdf"
SPECIAL_FILE='report [final] $draft.pdf'

printf 'Newline filename content\n' \
    > "$SOURCE_DIR/$NEWLINE_FILE"

printf 'Tab filename content\n' \
    > "$SOURCE_DIR/$TAB_FILE"

printf 'Leading dash filename content\n' \
    > "$SOURCE_DIR/$DASH_FILE"

printf 'Special filename content\n' \
    > "$NESTED_DIR/$SPECIAL_FILE"


# --------------------------------------------------
# Execute the script with an explicit source directory
# --------------------------------------------------

output="$(zsh -f "$SCRIPT_PATH" "$SOURCE_DIR" 2>&1)"
actual_exit_code=$?

assert_equal \
    0 \
    "$actual_exit_code" \
    "Unusual filenames and directory names are processed successfully"

if (( actual_exit_code != 0 )); then
    print -u2 -- "Script output:"
    print -u2 -r -- "$output"
fi


# --------------------------------------------------
# Verify unusual filenames
# --------------------------------------------------

assert_file_exists \
    "$OUTPUT_DIR/${NEWLINE_FILE%.pdf}.md" \
    "A filename containing a newline is processed correctly"

assert_file_exists \
    "$OUTPUT_DIR/${TAB_FILE%.pdf}.md" \
    "A filename containing a tab is processed correctly"

assert_file_exists \
    "$OUTPUT_DIR/${DASH_FILE%.pdf}.md" \
    "A filename beginning with a dash is processed correctly"


# --------------------------------------------------
# Verify unusual directory and nested filename
# --------------------------------------------------

assert_directory_exists \
    "$OUTPUT_DIR/${NESTED_NAME} Markdown" \
    "A directory containing a newline and special characters is preserved"

assert_file_exists \
    "$OUTPUT_DIR/${NESTED_NAME} Markdown/${SPECIAL_FILE%.pdf}.md" \
    "A nested filename with spaces and special characters is processed"


# --------------------------------------------------
# Verify converted content
# --------------------------------------------------

assert_equal \
    "Mock converted content" \
    "$(< "$OUTPUT_DIR/${NEWLINE_FILE%.pdf}.md")" \
    "The newline filename receives valid converted content"

assert_equal \
    "Mock converted content" \
    "$(< "$OUTPUT_DIR/${NESTED_NAME} Markdown/${SPECIAL_FILE%.pdf}.md")" \
    "The nested special filename receives valid converted content"


# --------------------------------------------------
# Verify original files remain intact
# --------------------------------------------------

assert_file_exists \
    "$SOURCE_DIR/$NEWLINE_FILE" \
    "The original newline filename remains intact"

assert_file_exists \
    "$SOURCE_DIR/$TAB_FILE" \
    "The original tab filename remains intact"

assert_file_exists \
    "$SOURCE_DIR/$DASH_FILE" \
    "The original leading dash filename remains intact"


# --------------------------------------------------
# Verify conversion count
# --------------------------------------------------

typeset -i MOCK_CALLS=0

while IFS= read -r mock_record; do
    (( ++MOCK_CALLS ))
done < "$MOCK_LOG"

assert_equal \
    4 \
    "$MOCK_CALLS" \
    "All four unusual source files are processed exactly once"


# --------------------------------------------------
# Test 2: Default source directory
# --------------------------------------------------

DEFAULT_SOURCE_DIR="$TEMP_DIR/default source"
DEFAULT_OUTPUT_DIR="$DEFAULT_SOURCE_DIR/${DEFAULT_SOURCE_DIR:t} Markdown"

mkdir -p "$DEFAULT_SOURCE_DIR" || {
    print -u2 -- "Error: Could not create default source directory."
    exit 2
}

printf 'Default source document\n' > "$DEFAULT_SOURCE_DIR/default.pdf"

: > "$MOCK_LOG"

default_output="$(
    cd "$DEFAULT_SOURCE_DIR" &&
        zsh -f "$SCRIPT_PATH" 2>&1
)"
actual_exit_code=$?

assert_equal \
    0 \
    "$actual_exit_code" \
    "Execution without arguments uses the current directory successfully"

assert_directory_exists \
    "$DEFAULT_OUTPUT_DIR" \
    "The default output directory is created inside the current directory"

assert_file_exists \
    "$DEFAULT_OUTPUT_DIR/default.md" \
    "The file in the default source directory is converted"

assert_contains \
    "${(q)DEFAULT_SOURCE_DIR}" \
    "$default_output" \
    "The final summary identifies the current directory as the source"


# --------------------------------------------------
# Verify default conversion count
# --------------------------------------------------

typeset -i DEFAULT_MOCK_CALLS=0

while IFS= read -r mock_record; do
    (( ++DEFAULT_MOCK_CALLS ))
done < "$MOCK_LOG"

assert_equal \
    1 \
    "$DEFAULT_MOCK_CALLS" \
    "The default source file is converted exactly once"


# --------------------------------------------------
# Report results
# --------------------------------------------------

test_summary
