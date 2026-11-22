
#!/usr/bin/env zsh

# Integration tests for directory structure preservation.

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

# Mock executable used to satisfy the dependency check.
# No file conversion is required in these tests.

exit 0
MOCK

chmod +x "$MOCK_BIN/markitdown" || {
    print -u2 -- "Error: Could not prepare mock executable."
    exit 2
}

export PATH="$MOCK_BIN:$PATH"


# --------------------------------------------------
# Create source directory structure
# --------------------------------------------------

SOURCE_DIR="$TEMP_DIR/source tree"
OUTPUT_DIR="$SOURCE_DIR/${SOURCE_DIR:t} Markdown"

mkdir -p \
    "$SOURCE_DIR/empty folder" \
    "$SOURCE_DIR/another empty folder" \
    "$SOURCE_DIR/level one/level two/level three with spaces" || {
        print -u2 -- "Error: Could not create source directory structure."
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
    "The script processes the directory structure successfully"

if (( actual_exit_code != 0 )); then
    print -u2 -- "Script output:"
    print -u2 -r -- "$output"
fi


# --------------------------------------------------
# Output root directory
# --------------------------------------------------

assert_directory_exists \
    "$OUTPUT_DIR" \
    "The output root directory is created inside the source directory"

assert_directory_not_exists \
    "$TEMP_DIR/source tree Markdown" \
    "The output root is not created beside the source directory"


# --------------------------------------------------
# Empty directory preservation
# --------------------------------------------------

assert_directory_exists \
    "$OUTPUT_DIR/empty folder Markdown" \
    "An empty directory is preserved"

assert_directory_exists \
    "$OUTPUT_DIR/another empty folder Markdown" \
    "Multiple empty directories are preserved"


# --------------------------------------------------
# Nested directory preservation
# --------------------------------------------------

assert_directory_exists \
    "$OUTPUT_DIR/level one Markdown" \
    "The first directory level is preserved"

assert_directory_exists \
    "$OUTPUT_DIR/level one Markdown/level two Markdown" \
    "The second directory level is preserved"

assert_directory_exists \
    "$OUTPUT_DIR/level one Markdown/level two Markdown/level three with spaces Markdown" \
    "The third directory level and its spaces are preserved"


# --------------------------------------------------
# Verify directory hierarchy
# --------------------------------------------------

assert_directory_not_exists \
    "$OUTPUT_DIR/level two Markdown" \
    "Second-level directories are not flattened"

assert_directory_not_exists \
    "$OUTPUT_DIR/level three with spaces Markdown" \
    "Third-level directories are not moved to the root"


# --------------------------------------------------
# Verify source remains unchanged
# --------------------------------------------------

assert_directory_exists \
    "$SOURCE_DIR" \
    "The original source directory remains intact"


# --------------------------------------------------
# Report results
# --------------------------------------------------

test_summary
