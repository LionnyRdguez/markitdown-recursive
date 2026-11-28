#!/usr/bin/env zsh

# ------------------------------------------------------------------------------
# 1. Initial setup
# ------------------------------------------------------------------------------

# Ensures Zsh behavior and prevents inherited user options
# (for example, special globbing or errexit) from changing how the script works.
# We do not enable errexit: we want to record an error and continue processing
# the remaining files when --continue is enabled.
emulate -R zsh
setopt pipefail

# Global variables used by the functions and by the cleanup block.
# REPLY is a special Zsh variable used to return values from functions without
# relying on command substitution.
SOURCE_ARG=""
SOURCE_DIR=""
SOURCE_NAME=""
OUTPUT_ROOT=""
OUTPUT_DIR_NAME=""
OUTPUT_FILE=""
WORK_DIR=""
MANIFEST=""
SORTED_MANIFEST=""
SCAN_TMP=""
BODY_TMP=""
FILE_TMP=""
CONTENT_TMP=""
ERROR_TMP=""
WARNINGS_TMP=""
TEMP_OUTPUT=""
OUTPUT_CREATED=0
OUTPUT_COMMITTED=0

ALL_MODE=0
CONTINUE_MODE=0
DIRECTORY_SEEN=0
FILES_INCLUDED=0
FILES_SKIPPED=0
DIRECTORIES_SKIPPED=0
CANDIDATE_FILES=0
WARNING_COUNT=0

# ------------------------------------------------------------------------------
# 2. Help functions: messages, usage, and error output
# ------------------------------------------------------------------------------

usage() {
  cat <<'EOF_HELP'
Usage:
  ./MarkdownMerger.zsh [OPTIONS] [DIRECTORY]

Arguments:
  DIRECTORY       Directory whose Markdown files will be collected.
                  If omitted, the current working directory is used.

Options:
  --all           Search recursively through valid subdirectories.
  --continue      Continue after recoverable errors and skip affected items.
  -h, --help      Show this help message.

Examples:
  ./MarkdownMerger.zsh
  ./MarkdownMerger.zsh --all
  ./MarkdownMerger.zsh --continue
  ./MarkdownMerger.zsh --all --continue "/path/Documents Markdown"
  ./MarkdownMerger.zsh --continue --all "/path/Documents Markdown"

The combined document is saved inside a new directory in the source directory.
Existing output paths are never overwritten or reused.
Hidden files, hidden directories, and symbolic links are not processed.
Only regular .md and .markdown files are included.
EOF_HELP
}

# Displays an error and exits with code 2, reserved for problems that prevent the
# process from starting (arguments, dependencies, source folder, etc.).
die() {
  print -u2 -r -- "Error: $*"
  exit 2
}

# Displays a processing error and exits with code 1.
processing_error() {
  print -u2 -r -- "Error: $*"
  exit 1
}

# ------------------------------------------------------------------------------
# 3. Temporary file cleanup
# ------------------------------------------------------------------------------

# Removes temporary files and directories created by this execution. The output
# directory is removed only when this execution created it, it was not committed,
# and it is still empty.
cleanup() {
  local exit_status=$?
  local cleanup_failed=0

  # Prevents the EXIT trap from being invoked again by the exit at the end.
  trap - EXIT

  if [[ -n "$TEMP_OUTPUT" && -f "$TEMP_OUTPUT" && ! -L "$TEMP_OUTPUT" ]]; then
    if ! command rm -f -- "$TEMP_OUTPUT" 2>/dev/null; then
      print -u2 -r -- "Warning: could not remove temporary output file: ${(q)TEMP_OUTPUT}"
      cleanup_failed=1
    fi
  fi

  if [[ -n "$WORK_DIR" && -d "$WORK_DIR" && ! -L "$WORK_DIR" ]]; then
    if ! command rm -rf -- "$WORK_DIR" 2>/dev/null; then
      print -u2 -r -- "Warning: could not remove temporary working directory: ${(q)WORK_DIR}"
      cleanup_failed=1
    fi
  fi

  if (( OUTPUT_CREATED && ! OUTPUT_COMMITTED )); then
    if [[ -d "$OUTPUT_ROOT" && ! -L "$OUTPUT_ROOT" ]]; then
      if ! command rmdir -- "$OUTPUT_ROOT" 2>/dev/null; then
        print -u2 -r -- "Warning: the output directory could not be removed because it is not empty or is no longer safe: ${(q)OUTPUT_ROOT}"
        cleanup_failed=1
      fi
    fi
  fi

  if (( cleanup_failed && exit_status == 0 )); then
    exit_status=1
  fi

  exit "$exit_status"
}

# EXIT runs cleanup when the script exits. INT and TERM are converted to standard
# exit codes; cleanup will also run on exit.
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# ------------------------------------------------------------------------------
# 4. Argument parsing
# ------------------------------------------------------------------------------

# Help is accepted on its own so that it cannot hide another invalid argument.
if (( $# == 1 )) && [[ "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  exit 0
fi

for argument in "$@"; do
  if (( DIRECTORY_SEEN )); then
    case "$argument" in
      -* )
        usage
        die "options must appear before the directory argument: ${(q)argument}"
        ;;
      * )
        usage
        die "more than one directory argument was received."
        ;;
    esac
  fi

  case "$argument" in
    --all)
      (( ALL_MODE )) && { usage; die "the --all option was repeated."; }
      ALL_MODE=1
      ;;
    --continue)
      (( CONTINUE_MODE )) && { usage; die "the --continue option was repeated."; }
      CONTINUE_MODE=1
      ;;
    -h|--help)
      usage
      die "the help option must be used on its own."
      ;;
    -* )
      usage
      die "unknown option: ${(q)argument}"
      ;;
    * )
      SOURCE_ARG="$argument"
      DIRECTORY_SEEN=1
      ;;
  esac
done

# Uses the current working directory when no source directory was provided.
if (( ! DIRECTORY_SEEN )); then
  SOURCE_ARG="."
fi

# Removes trailing slashes before checking whether the source itself is a
# symbolic link. A single slash is preserved for the root-directory check.
while [[ "$SOURCE_ARG" == */ && "$SOURCE_ARG" != "/" ]]; do
  SOURCE_ARG="${SOURCE_ARG%/}"
done

# ------------------------------------------------------------------------------
# 5. Source validation and output naming
# ------------------------------------------------------------------------------

# The source directory itself must not be a symbolic link. -L also detects broken
# symbolic links, which -e alone does not detect.
if [[ -L "$SOURCE_ARG" ]]; then
  die "the source directory cannot be a symbolic link: ${(q)SOURCE_ARG}"
fi

if [[ ! -d "$SOURCE_ARG" ]]; then
  die "the path does not exist or is not a directory: ${(q)SOURCE_ARG}"
fi

builtin cd -P -- "$SOURCE_ARG" 2>/dev/null || \
  die "could not access the source directory: ${(q)SOURCE_ARG}"

# PWD now contains the absolute physical source path.
SOURCE_DIR="$PWD"

# The filesystem root is not accepted as a source directory.
[[ "$SOURCE_DIR" != "/" ]] || \
  die "the filesystem root cannot be used as the source directory."

SOURCE_NAME="${SOURCE_DIR:t}"

# If the source name already ends in "Markdown" (case-insensitive), preserve
# its original spelling and append " Merged". Otherwise append " Markdown Merged".
if [[ "${SOURCE_NAME:l}" == *markdown ]]; then
  OUTPUT_DIR_NAME="${SOURCE_NAME} Merged"
else
  OUTPUT_DIR_NAME="${SOURCE_NAME} Markdown Merged"
fi

OUTPUT_ROOT="${SOURCE_DIR}/${OUTPUT_DIR_NAME}"

# The document name is based on the source directory name. The suffix "Markdown"
# is removed when present, and all literal spaces are then removed.
DOCUMENT_STEM="$SOURCE_NAME"
if [[ "${SOURCE_NAME:l}" == *markdown ]]; then
  if (( ${#SOURCE_NAME} > 8 )); then
    DOCUMENT_STEM="${SOURCE_NAME[1,$(( ${#SOURCE_NAME} - 8 ))]}"
  else
    DOCUMENT_STEM=""
  fi
fi
DOCUMENT_STEM="${DOCUMENT_STEM// /}"

if (( ALL_MODE )); then
  OUTPUT_FILE="${OUTPUT_ROOT}/${DOCUMENT_STEM}MarkdownContextAll.md"
else
  OUTPUT_FILE="${OUTPUT_ROOT}/${DOCUMENT_STEM}MarkdownContext.md"
fi

# The source directory must be readable and searchable before traversal starts.
[[ -r "$SOURCE_DIR" && -x "$SOURCE_DIR" ]] || \
  die "the source directory is not readable or searchable: ${(q)SOURCE_DIR}"

# A pre-existing output path is always a fatal conflict, even when the current
# search would otherwise find no Markdown files. The path is checked again just
# before creation to cover changes made by another process during the scan.
if [[ -e "$OUTPUT_ROOT" || -L "$OUTPUT_ROOT" ]]; then
  die "the output path is already occupied: ${(q)OUTPUT_ROOT}"
fi

# ------------------------------------------------------------------------------
# 6. Dependency checks and temporary workspace
# ------------------------------------------------------------------------------

# The following tools are used to traverse, sort, read, and safely publish files.
# GNU find and GNU sort are required for the options used by this script.
for dependency in find sort mktemp mkdir mv rm rmdir cat tail od; do
  command -v "$dependency" >/dev/null 2>&1 || \
    die "required dependency not found: $dependency"
done

# -print0 / sort -z are needed to handle names with spaces, newlines, and special
# characters. This small test checks that sort accepts the NUL delimiter.
command sort -z </dev/null >/dev/null 2>&1 || \
  die "the 'sort' version does not support -z; GNU sort is required."

# The temporary directory name begins with a dot. If TMPDIR is inside the source
# tree, the search rules will therefore exclude this working directory.
WORK_DIR="$(command mktemp -d "${TMPDIR:-/tmp}/.markdown-merger.XXXXXXXX")" || \
  die "could not create the temporary working directory."

[[ -d "$WORK_DIR" && ! -L "$WORK_DIR" ]] || \
  die "the temporary working directory is not safe: ${(q)WORK_DIR}"

MANIFEST="${WORK_DIR}/manifest"
SORTED_MANIFEST="${WORK_DIR}/manifest-sorted"
SCAN_TMP="${WORK_DIR}/scan"
BODY_TMP="${WORK_DIR}/combined-body"
FILE_TMP="${WORK_DIR}/current-file"
CONTENT_TMP="${WORK_DIR}/current-content"
ERROR_TMP="${WORK_DIR}/error"
WARNINGS_TMP="${WORK_DIR}/warnings.jsonl"

for temporary_file in "$MANIFEST" "$SORTED_MANIFEST" "$SCAN_TMP" "$BODY_TMP" "$FILE_TMP" "$CONTENT_TMP" "$ERROR_TMP" "$WARNINGS_TMP"; do
  : >| "$temporary_file" || \
    die "could not initialize a temporary file: ${(q)temporary_file}"
done

# ------------------------------------------------------------------------------
# 7. JSON escaping and warning records
# ------------------------------------------------------------------------------

# Escapes a string so it can be safely written as a JSON string value. Control
# characters are encoded as \u00XX; common ones use their shorter JSON forms.
# The escaped value is returned through REPLY.
json_escape() {
  local value="$1"
  local character
  local escaped=""
  local -i character_code

  for character in "${(@s::)value}"; do
    if [[ "$character" == $'\\' ]]; then
      escaped+="\\\\"
    elif [[ "$character" == '"' ]]; then
      escaped+='\"'
    elif [[ "$character" == $'\b' ]]; then
      escaped+='\b'
    elif [[ "$character" == $'\f' ]]; then
      escaped+='\f'
    elif [[ "$character" == $'\n' ]]; then
      escaped+='\n'
    elif [[ "$character" == $'\r' ]]; then
      escaped+='\r'
    elif [[ "$character" == $'\t' ]]; then
      escaped+='\t'
    else
      printf -v character_code '%d' "'$character"
      if (( character_code < 32 )); then
        printf -v character '\\u%04x' "$character_code"
        escaped+="$character"
      else
        escaped+="$character"
      fi
    fi
  done

  REPLY="$escaped"
}

# Identifies errors that indicate a destination or temporary-storage write failure.
# These are always fatal, including in --continue mode: skipping a file cannot make
# a failed write safe or produce a trustworthy collection.
is_write_failure() {
  local message_lower="${1:l}"
  [[ "$message_lower" == *"write error"* || \
     "$message_lower" == *"no space left on device"* || \
     "$message_lower" == *"disk quota exceeded"* || \
     "$message_lower" == *"file too large"* || \
     "$message_lower" == *"failed to write"* || \
     "$message_lower" == *"read-only file system"* ]]
}

# Appends a JSON Lines warning record. Each path is relative to SOURCE_DIR.
add_warning() {
  local relative_path="$1"
  local problem_type="$2"
  local message="$3"
  local path_json
  local type_json
  local message_json

  json_escape "$relative_path"
  path_json="$REPLY"
  json_escape "$problem_type"
  type_json="$REPLY"
  json_escape "$message"
  message_json="$REPLY"

  printf '{"path":"%s","type":"%s","message":"%s"}\n' \
    "$path_json" "$type_json" "$message_json" >> "$WARNINGS_TMP" || return 1

  (( WARNING_COUNT += 1 ))
  return 0
}

# ------------------------------------------------------------------------------
# 8. Initial summary
# ------------------------------------------------------------------------------

print ""
print "Markdown Merger"
print -r -- "Source: ${SOURCE_NAME}"
if (( ALL_MODE )); then
  print "Mode: Recursive"
else
  print "Mode: Non-recursive"
fi
if (( CONTINUE_MODE )); then
  print "Error handling: Continue"
else
  print "Error handling: Strict"
fi
print ""

# ------------------------------------------------------------------------------
# 9. Building the initial file manifest
# ------------------------------------------------------------------------------

# The directory queue allows each directory to be enumerated separately. This is
# necessary because --continue must be able to skip one inaccessible subdirectory
# without treating the entire source-tree traversal as successful.
typeset -a PENDING_DIRS
PENDING_DIRS=("$SOURCE_DIR")
QUEUE_INDEX=1

while (( QUEUE_INDEX <= ${#PENDING_DIRS[@]} )); do
  CURRENT_DIR="${PENDING_DIRS[$QUEUE_INDEX]}"
  (( QUEUE_INDEX += 1 ))

  # A child directory may disappear or become a symbolic link after it was queued.
  # The source root is fatal in either case; a child directory follows the selected
  # strict/continue error policy.
  if [[ ! -d "$CURRENT_DIR" || -L "$CURRENT_DIR" ]]; then
    if [[ "$CURRENT_DIR" == "$SOURCE_DIR" ]]; then
      die "the source directory became unavailable during traversal: ${(q)SOURCE_DIR}"
    fi

    RELATIVE_DIR="${CURRENT_DIR#"$SOURCE_DIR"/}"
    DIRECTORY_MESSAGE="The directory disappeared, became a symbolic link, or is no longer accessible."

    if (( CONTINUE_MODE )); then
      if ! add_warning "$RELATIVE_DIR" "directory-unavailable" "$DIRECTORY_MESSAGE"; then
        processing_error "could not record a directory warning for: ${(q)RELATIVE_DIR}"
      fi
      print -u2 -r -- "Warning: skipped directory: ${(q)RELATIVE_DIR}"
      (( DIRECTORIES_SKIPPED += 1 ))
      continue
    fi

    processing_error "directory became unavailable during traversal: ${(q)RELATIVE_DIR}"
  fi

  : >| "$SCAN_TMP" || \
    processing_error "could not reset the temporary directory listing."
  : >| "$ERROR_TMP" || \
    processing_error "could not reset the temporary error file."

  if (( ALL_MODE )); then
    # Enumerates only direct children. Hidden directories and previous merged
    # output directories are pruned before their contents can be inspected.
    if LC_ALL=C command find "$CURRENT_DIR" -mindepth 1 -maxdepth 1 \
      \( -name '.*' -o \( -type d -iname '* Markdown Merged' \) \) -prune -o \
      \( -type d -o \( -type f \( -iname '*.md' -o -iname '*.markdown' \) \) \) \
      -print0 >| "$SCAN_TMP" 2> "$ERROR_TMP"; then
      FIND_STATUS=0
    else
      FIND_STATUS=$?
    fi
  else
    # The non-recursive mode examines only regular Markdown files immediately
    # inside the source directory.
    if LC_ALL=C command find "$CURRENT_DIR" -mindepth 1 -maxdepth 1 \
      -name '.*' -prune -o -type f \( -iname '*.md' -o -iname '*.markdown' \) \
      -print0 >| "$SCAN_TMP" 2> "$ERROR_TMP"; then
      FIND_STATUS=0
    else
      FIND_STATUS=$?
    fi
  fi

  if (( FIND_STATUS != 0 )); then
    FIND_MESSAGE="$(< "$ERROR_TMP")"
    [[ -n "$FIND_MESSAGE" ]] || FIND_MESSAGE="The directory could not be enumerated."
    FIND_MESSAGE="${FIND_MESSAGE//"$CURRENT_DIR"/"${CURRENT_DIR#"$SOURCE_DIR"/}"}"

    if is_write_failure "$FIND_MESSAGE"; then
      processing_error "a temporary-storage write failed while enumerating: ${(q)CURRENT_DIR}"
    fi

    if [[ "$CURRENT_DIR" == "$SOURCE_DIR" ]]; then
      die "could not enumerate the source directory: ${(q)FIND_MESSAGE}"
    fi

    RELATIVE_DIR="${CURRENT_DIR#"$SOURCE_DIR"/}"
    if (( CONTINUE_MODE )); then
      DIRECTORY_MESSAGE="Directory enumeration failed. All content under this directory was excluded; the number of files is unknown. ${FIND_MESSAGE}"
      if ! add_warning "$RELATIVE_DIR" "directory-enumeration-error" "$DIRECTORY_MESSAGE"; then
        processing_error "could not record a directory warning for: ${(q)RELATIVE_DIR}"
      fi
      print -u2 -r -- "Warning: skipped directory: ${(q)RELATIVE_DIR}"
      print -u2 -r -- "  ${(q)FIND_MESSAGE}"
      (( DIRECTORIES_SKIPPED += 1 ))
      continue
    fi

    processing_error "could not enumerate directory ${(q)RELATIVE_DIR}: ${(q)FIND_MESSAGE}"
  fi

  # Paths are NUL-delimited so filenames containing spaces, tabs, or newlines
  # remain intact. The final manifest is sorted after every directory is scanned.
  while IFS= read -r -d '' entry; do
    if [[ -d "$entry" && ! -L "$entry" ]]; then
      if (( ALL_MODE )); then
        PENDING_DIRS+=("$entry")
      fi
    elif [[ -f "$entry" && ! -L "$entry" ]]; then
      printf '%s\0' "$entry" >> "$MANIFEST" || \
        processing_error "could not append a path to the temporary manifest."
      (( CANDIDATE_FILES += 1 ))
    fi
  done < "$SCAN_TMP"
done

# Sorts the complete inventory using NUL as the delimiter and locale C. All paths
# share the same source prefix, so sorting their absolute paths produces the same
# order as sorting their complete relative paths.
LC_ALL=C command sort -z "$MANIFEST" -o "$SORTED_MANIFEST" || \
  processing_error "could not sort the Markdown file manifest."

# A successful search with no candidates creates neither an output directory nor
# an empty document. Directory-enumeration warnings mean the search was incomplete.
if (( CANDIDATE_FILES == 0 )); then
  if (( DIRECTORIES_SKIPPED > 0 )); then
    print ""
    print "Collection could not be generated: no Markdown files were collected from the directories that could be examined."
    print -r -- "Directories skipped: $DIRECTORIES_SKIPPED"
    print "Collection status: PARTIAL"
    print "Exit code: 1"
    exit 1
  fi

  print "No Markdown files found. No output was created."
  exit 0
fi

# ------------------------------------------------------------------------------
# 10. Reading files and building the combined body
# ------------------------------------------------------------------------------

while IFS= read -r -d '' source_file; do
  RELATIVE_PATH="${source_file#"$SOURCE_DIR"/}"

  : >| "$FILE_TMP" || \
    processing_error "could not reset the temporary file buffer."
  : >| "$CONTENT_TMP" || \
    processing_error "could not reset the temporary content buffer."
  : >| "$ERROR_TMP" || \
    processing_error "could not reset the temporary error file."

  # Revalidate immediately before opening the source path. The initial manifest
  # is fixed, but files may disappear, become symlinks, or change type meanwhile.
  if [[ ! -e "$source_file" && ! -L "$source_file" ]]; then
    FILE_MESSAGE="The file disappeared after the initial search."
    FILE_ERROR_TYPE="file-disappeared"
  elif [[ -L "$source_file" || ! -f "$source_file" ]]; then
    FILE_MESSAGE="The path is no longer a regular file."
    FILE_ERROR_TYPE="not-a-regular-file"
  elif [[ ! -r "$source_file" ]]; then
    FILE_MESSAGE="The file is not readable in the current session."
    FILE_ERROR_TYPE="file-unreadable"
  else
    FILE_MESSAGE=""
    FILE_ERROR_TYPE=""
  fi

  if [[ -n "$FILE_ERROR_TYPE" ]]; then
    if (( CONTINUE_MODE )); then
      if ! add_warning "$RELATIVE_PATH" "$FILE_ERROR_TYPE" "$FILE_MESSAGE"; then
        processing_error "could not record a file warning for: ${(q)RELATIVE_PATH}"
      fi
      print -u2 -r -- "Warning: skipped file: ${(q)RELATIVE_PATH}"
      (( FILES_SKIPPED += 1 ))
      continue
    fi

    processing_error "${FILE_MESSAGE} Path: ${(q)RELATIVE_PATH}"
  fi

  FILE_NUMBER=$(( FILES_INCLUDED + 1 ))
  FILE_NUMBER_PADDED="$(printf '%06d' "$FILE_NUMBER")"

  # Reads each source into a dedicated temporary content file first. This separates
  # input errors from failures while writing the generated metadata and separators.
  if ! LC_ALL=C command cat -- "$source_file" >> "$CONTENT_TMP" 2> "$ERROR_TMP"; then
    FILE_OS_MESSAGE="$(< "$ERROR_TMP")"
    FILE_OS_MESSAGE="${FILE_OS_MESSAGE//"$source_file"/"$RELATIVE_PATH"}"
    [[ -n "$FILE_OS_MESSAGE" ]] || FILE_OS_MESSAGE="The file could not be read."

    if is_write_failure "$FILE_OS_MESSAGE"; then
      processing_error "a temporary-storage write failed while staging: ${(q)RELATIVE_PATH}"
    fi

    if (( CONTINUE_MODE )); then
      FILE_MESSAGE="The file could not be read. ${FILE_OS_MESSAGE}"
      if ! add_warning "$RELATIVE_PATH" "file-read-error" "$FILE_MESSAGE"; then
        processing_error "could not record a read warning for: ${(q)RELATIVE_PATH}"
      fi
      print -u2 -r -- "Warning: skipped file: ${(q)RELATIVE_PATH}"
      print -u2 -r -- "  ${(q)FILE_OS_MESSAGE}"
      (( FILES_SKIPPED += 1 ))
      continue
    fi

    processing_error "could not read ${(q)RELATIVE_PATH}: ${(q)FILE_OS_MESSAGE}"
  fi

  # Builds the opening marker and source metadata after the source content has been
  # read successfully. The relative path is JSON-escaped to support unusual chars.
  json_escape "$RELATIVE_PATH"
  RELATIVE_PATH_JSON="$REPLY"

  {
    print -r -- "============================================================"
    print -r -- "MARKDOWNMERGER - BEGIN FILE ${FILE_NUMBER_PADDED}"
    print -r -- "============================================================"
    print ""
    printf 'SOURCE: {"path":"%s"}\n\n' "$RELATIVE_PATH_JSON"
  } >| "$FILE_TMP" || \
    processing_error "could not write the opening metadata for: ${(q)RELATIVE_PATH}"

  # Appending the successfully staged source content is an output operation. Any
  # failure here is fatal, even when --continue is enabled.
  command cat -- "$CONTENT_TMP" >> "$FILE_TMP" || \
    processing_error "could not append staged content for: ${(q)RELATIVE_PATH}"

  # Inspects the final byte of the staged content rather than reopening the source.
  # This avoids a second race with a source file that changes or disappears.
  : >| "$ERROR_TMP" || \
    processing_error "could not reset the temporary error file."
  if ! LAST_BYTE_HEX="$(command tail -c 1 -- "$CONTENT_TMP" 2> "$ERROR_TMP" | command od -An -t x1 2>> "$ERROR_TMP")"; then
    FILE_OS_MESSAGE="$(< "$ERROR_TMP")"
    [[ -n "$FILE_OS_MESSAGE" ]] || FILE_OS_MESSAGE="could not inspect the staged source content."
    processing_error "could not inspect staged content for ${(q)RELATIVE_PATH}: ${(q)FILE_OS_MESSAGE}"
  fi

  LAST_BYTE_HEX="${LAST_BYTE_HEX//[[:space:]]/}"
  if [[ "$LAST_BYTE_HEX" == "0a" ]]; then
    printf '\n' >> "$FILE_TMP" || \
      processing_error "could not add the separator after: ${(q)RELATIVE_PATH}"
  else
    printf '\n\n' >> "$FILE_TMP" || \
      processing_error "could not add the separator after: ${(q)RELATIVE_PATH}"
  fi

  {
    print -r -- "============================================================"
    print -r -- "MARKDOWNMERGER - END FILE ${FILE_NUMBER_PADDED}"
    print -r -- "============================================================"
    print ""
  } >> "$FILE_TMP" || \
    processing_error "could not write the closing marker for: ${(q)RELATIVE_PATH}"

  # Appends a fully read and validated segment to the combined body.
  command cat -- "$FILE_TMP" >> "$BODY_TMP" || \
    processing_error "could not append the content of: ${(q)RELATIVE_PATH}"

  (( FILES_INCLUDED += 1 ))
done < "$SORTED_MANIFEST"

# If all candidates were skipped, no output directory or document is created.
if (( FILES_INCLUDED == 0 )); then
  print ""
  print "Collection could not be generated: no usable Markdown files remain."
  print -r -- "Files skipped: $FILES_SKIPPED"
  print -r -- "Directories skipped: $DIRECTORIES_SKIPPED"
  print "Collection status: PARTIAL"
  print "Exit code: 1"
  exit 1
fi

# ------------------------------------------------------------------------------
# 11. Output directory validation and safe publication
# ------------------------------------------------------------------------------

# The output path must be completely unused. -L also detects broken symbolic links.
if [[ -e "$OUTPUT_ROOT" || -L "$OUTPUT_ROOT" ]]; then
  die "the output path is already occupied: ${(q)OUTPUT_ROOT}"
fi

# Creates only the output root. The final document is published only after it has
# been written completely to a temporary file inside this same directory.
if ! command mkdir -- "$OUTPUT_ROOT" 2>/dev/null; then
  die "could not create the output directory: ${(q)OUTPUT_ROOT}"
fi
OUTPUT_CREATED=1

# A second check covers the uncommon case where another process changed the path
# between the initial check and creation.
[[ -d "$OUTPUT_ROOT" && ! -L "$OUTPUT_ROOT" ]] || \
  processing_error "the output directory is not a safe directory: ${(q)OUTPUT_ROOT}"

TEMP_OUTPUT="$(command mktemp "${OUTPUT_ROOT}/.markdown-merger-output.XXXXXXXX")" || \
  processing_error "could not create the temporary output document."

[[ -f "$TEMP_OUTPUT" && ! -L "$TEMP_OUTPUT" ]] || \
  processing_error "the temporary output path is not a regular file: ${(q)TEMP_OUTPUT}"

# Writes the final header, the completed body, and any collection warnings. Every
# write is checked so a disk-full or filesystem error cannot be reported as success.
write_document() {
  if ! {
    print -r -- "# Combined Markdown Context" || return 1
    print "" || return 1
    print -r -- "Generated by: Markdown Merger" || return 1
    print -r -- "Source directory: ${SOURCE_NAME}" || return 1

    if (( ALL_MODE )); then
      print -r -- "Collection mode: Recursive" || return 1
    else
      print -r -- "Collection mode: Non-recursive" || return 1
    fi

    if (( FILES_SKIPPED > 0 || DIRECTORIES_SKIPPED > 0 )); then
      print -r -- "Collection status: PARTIAL" || return 1
    else
      print -r -- "Collection status: COMPLETE" || return 1
    fi

    print -r -- "Files included: ${FILES_INCLUDED}" || return 1
    print -r -- "Files skipped: ${FILES_SKIPPED}" || return 1
    print -r -- "Directories skipped: ${DIRECTORIES_SKIPPED}" || return 1
    print "" || return 1

    command cat -- "$BODY_TMP" || return 1

    if (( WARNING_COUNT > 0 )); then
      print -r -- "# Collection Warnings" || return 1
      print "" || return 1
      print -r -- "The following files or directories were omitted during collection:" || return 1
      print "" || return 1
      print -r -- '```jsonl' || return 1
      command cat -- "$WARNINGS_TMP" || return 1
      print -r -- '```' || return 1
    fi
  } >| "$TEMP_OUTPUT"; then
    return 1
  fi

  return 0
}

if ! write_document; then
  processing_error "could not write the combined Markdown document."
fi

# Publishes without overwriting a destination that another process may have
# created after the initial check. -T treats the destination as a file path and
# -n prevents overwriting an existing item (GNU coreutils).
if command mv -nT -- "$TEMP_OUTPUT" "$OUTPUT_FILE"; then
  if [[ -e "$TEMP_OUTPUT" || -L "$TEMP_OUTPUT" ]]; then
    if [[ -e "$OUTPUT_FILE" || -L "$OUTPUT_FILE" ]]; then
      processing_error "the output file appeared during publication: ${(q)OUTPUT_FILE}"
    fi
    processing_error "could not publish the combined document: ${(q)OUTPUT_FILE}"
  fi
else
  processing_error "could not publish the combined document: ${(q)OUTPUT_FILE}"
fi

TEMP_OUTPUT=""
OUTPUT_COMMITTED=1

# Removes the temporary workspace before the final summary. The EXIT routine keeps
# a second cleanup attempt available if this operation fails.
TEMP_CLEANUP_ERRORS=0
if [[ -n "$WORK_DIR" && ( -e "$WORK_DIR" || -L "$WORK_DIR" ) ]]; then
  if [[ -d "$WORK_DIR" && ! -L "$WORK_DIR" ]] && command rm -rf -- "$WORK_DIR" 2>/dev/null; then
    WORK_DIR=""
  else
    print -u2 -r -- "Warning: could not remove temporary working directory: ${(q)WORK_DIR}"
    (( TEMP_CLEANUP_ERRORS += 1 ))
  fi
fi

# ------------------------------------------------------------------------------
# 12. Final summary and exit code
# ------------------------------------------------------------------------------

print ""
if (( FILES_SKIPPED > 0 || DIRECTORIES_SKIPPED > 0 )); then
  print "Collection completed with warnings."
elif (( TEMP_CLEANUP_ERRORS > 0 )); then
  print "Collection completed, but temporary cleanup reported errors."
else
  print "Collection completed successfully."
fi

print -r -- "Files included: $FILES_INCLUDED"
print -r -- "Files skipped: $FILES_SKIPPED"
print -r -- "Directories skipped: $DIRECTORIES_SKIPPED"
print -r -- "Temporary cleanup errors: $TEMP_CLEANUP_ERRORS"

if (( FILES_SKIPPED > 0 || DIRECTORIES_SKIPPED > 0 )); then
  print ""
  print "Collection status: PARTIAL"
else
  print ""
  print "Collection status: COMPLETE"
fi

print -r -- "Output: ${OUTPUT_DIR_NAME}/"
print -r -- "Document: ${OUTPUT_FILE:t}"

if (( FILES_SKIPPED > 0 || DIRECTORIES_SKIPPED > 0 || TEMP_CLEANUP_ERRORS > 0 )); then
  print "Exit code: 1"
  exit 1
fi

print "Exit code: 0"
exit 0
