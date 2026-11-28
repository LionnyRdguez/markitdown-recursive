
#!/usr/bin/env zsh

# End-to-end integration tests for MarkitdownRecursive.
# These tests use the real application and the real MarkItDown dependency.

emulate -LR zsh


# --------------------------------------------------
# Paths and test environment
# --------------------------------------------------

TEST_DIR="${0:A:h:h}"
PROJECT_ROOT="${TEST_DIR:h:h}"

source "$TEST_DIR/test-helpers.zsh"

SCRIPT_PATH="$PROJECT_ROOT/Zsh/MarkitdownRecursive.zsh"
FIXTURES_DIR="$TEST_DIR/fixtures/real-markitdown"
RESULTS_DIR="$TEST_DIR/results/real-markitdown"

TEMP_DIR="$(mktemp -d)" || {
    print -u2 -- "Error: Could not create temporary test directory."
    exit 2
}

cleanup() {
    rm -rf -- "$TEMP_DIR"
}

trap cleanup EXIT

SOURCE_DIR="$TEMP_DIR/source"
OUTPUT_DIR="$SOURCE_DIR/${SOURCE_DIR:t} Markdown"
SYSTEM_TMP_DIR="$TEMP_DIR/system-tmp"

mkdir -p "$SOURCE_DIR" "$SYSTEM_TMP_DIR" || {
    print -u2 -- "Error: Could not prepare the test environment."
    exit 2
}

typeset -a manifest_entries
typeset -a conversion_temp_entries


# --------------------------------------------------
# Verify real MarkItDown dependency
# --------------------------------------------------

if ! command -v markitdown >/dev/null 2>&1; then
    print -u2 -- "Error: MarkItDown must be installed to run end-to-end tests."

    assert_exit_code 0 command -v markitdown

    test_summary
    exit $?
fi

assert_exit_code 0 command -v markitdown


# --------------------------------------------------
# Prepare an isolated source copy
# --------------------------------------------------

assert_directory_exists \
    "$FIXTURES_DIR" \
    "The end-to-end fixture directory exists"

assert_directory_exists \
    "$RESULTS_DIR" \
    "The expected results directory exists"

if ! command cp -a "$FIXTURES_DIR/." "$SOURCE_DIR/"; then
    print -u2 -- "Error: Could not copy the source fixtures."
    exit 2
fi


# --------------------------------------------------
# Execute the actual application
# --------------------------------------------------

output="$(
    TMPDIR="$SYSTEM_TMP_DIR" \
        zsh -f "$SCRIPT_PATH" "$SOURCE_DIR" 2>&1
)"
actual_exit_code=$?

assert_equal \
    0 \
    "$actual_exit_code" \
    "MarkitdownRecursive processes all real fixtures successfully"

if (( actual_exit_code != 0 )); then
    print -u2 -- "Application output:"
    print -u2 -r -- "$output"
fi


# --------------------------------------------------
# Verify generated directory structure
# --------------------------------------------------

assert_directory_exists \
    "$OUTPUT_DIR" \
    "The application creates the output root directory"

assert_directory_exists \
    "$OUTPUT_DIR/nested Markdown" \
    "The application preserves the nested directory structure"


# --------------------------------------------------
# Verify generated files
# --------------------------------------------------

assert_file_exists \
    "$OUTPUT_DIR/plain-text.md" \
    "The plain text fixture is converted"

assert_file_exists \
    "$OUTPUT_DIR/existing-markdown.md" \
    "The existing Markdown fixture is copied"

assert_file_exists \
    "$OUTPUT_DIR/nested Markdown/nested-note.md" \
    "The nested text fixture is converted"


# --------------------------------------------------
# Compare generated output against reference results
# --------------------------------------------------

assert_exit_code 0 cmp -s \
    "$RESULTS_DIR/plain-text.md" \
    "$OUTPUT_DIR/plain-text.md"

assert_exit_code 0 cmp -s \
    "$RESULTS_DIR/existing-markdown.md" \
    "$OUTPUT_DIR/existing-markdown.md"

assert_exit_code 0 cmp -s \
    "$RESULTS_DIR/nested Markdown/nested-note.md" \
    "$OUTPUT_DIR/nested Markdown/nested-note.md"


# --------------------------------------------------
# Verify original source fixtures remain unchanged
# --------------------------------------------------

assert_exit_code 0 cmp -s \
    "$FIXTURES_DIR/plain-text.txt" \
    "$SOURCE_DIR/plain-text.txt"

assert_exit_code 0 cmp -s \
    "$FIXTURES_DIR/existing-markdown.md" \
    "$SOURCE_DIR/existing-markdown.md"

assert_exit_code 0 cmp -s \
    "$FIXTURES_DIR/nested/nested-note.txt" \
    "$SOURCE_DIR/nested/nested-note.txt"


# --------------------------------------------------
# Verify output file count
# --------------------------------------------------

generated_file_count="$(
    find "$OUTPUT_DIR" -type f -print |
        awk 'END { print NR + 0 }'
)"

assert_equal \
    3 \
    "$generated_file_count" \
    "Exactly three output files are generated"


# --------------------------------------------------
# Verify application summary
# --------------------------------------------------

regular_files_count="$(
    print -r -- "$output" |
        sed -n 's/^Regular files found:[[:space:]]*\([0-9][0-9]*\)$/\1/p'
)"

assert_equal \
    3 \
    "$regular_files_count" \
    "The application detects all three source files"

converted_count="$(
    print -r -- "$output" |
        sed -n 's/^Successfully converted:[[:space:]]*\([0-9][0-9]*\)$/\1/p'
)"

assert_equal \
    2 \
    "$converted_count" \
    "The application reports two successful conversions"

copied_count="$(
    print -r -- "$output" |
        sed -n 's/^Existing Markdown copied:[[:space:]]*\([0-9][0-9]*\)$/\1/p'
)"

assert_equal \
    1 \
    "$copied_count" \
    "The application reports one copied Markdown file"

failed_count="$(
    print -r -- "$output" |
        sed -n 's/^Failed conversions:[[:space:]]*\([0-9][0-9]*\)$/\1/p'
)"

assert_equal \
    0 \
    "$failed_count" \
    "The application reports no conversion failures"


# --------------------------------------------------
# Verify temporary files are removed
# --------------------------------------------------

manifest_entries=(
    "$SYSTEM_TMP_DIR"/markitdown-recursive.*(N)
    "$SYSTEM_TMP_DIR"/markitdown-recursive-sorted.*(N)
)

assert_equal \
    0 \
    "${#manifest_entries[@]}" \
    "Temporary manifest files are removed"

conversion_temp_entries=(
    "$OUTPUT_DIR"/.markitdown.*(N)
    "$OUTPUT_DIR/nested Markdown"/.markitdown.*(N)
)

assert_equal \
    0 \
    "${#conversion_temp_entries[@]}" \
    "Temporary conversion directories are removed"


# --------------------------------------------------
# Report results
# --------------------------------------------------

test_summary
