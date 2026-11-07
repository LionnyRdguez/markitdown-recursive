#!/usr/bin/env zsh

# ------------------------------------------------------------------------------
# 1. Initial setup
# ------------------------------------------------------------------------------

# Ensures Zsh behavior and prevents inherited user options
# (for example, special globbing or errexit) from changing how the script works.
# We do not enable errexit: we want to record an error and continue processing
# the remaining files.
emulate -R zsh

# Global variables used by the functions and by the cleanup block.
# REPLY is a special Zsh variable used to return paths from functions without
# relying on command substitution.
SOURCE_ARG=""
SOURCE_DIR=""
SOURCE_NAME=""
OUTPUT_ROOT=""
MANIFEST=""
SORTED_MANIFEST=""
CURRENT_TMP=""
CURRENT_TMP_DIR=""
TEMP_CLEANUP_ERRORS=0
typeset -a ORPHAN_TMP_DIRS

# ------------------------------------------------------------------------------
# 2. Help functions: messages, usage, and error output
# ------------------------------------------------------------------------------

usage() {
  cat <<'EOF'
Usage:
  ./MarkitdownRecursive.zsh [folder]

Arguments:
  folder     Folder to be processed. If omitted, the current directory is used.
  -h, --help Shows this help message.

The result is saved inside a folder named "Name Markdown".
Each visible subfolder also receives the suffix " Markdown".
Files keep their base name and receive the .md extension.

Hidden files/directories and symlinks are not processed. Existing .md files are
copied with their content intact. Results are never overwritten.
EOF
}

# Displays an error and exits with code 2, reserved for problems that prevent the
# process from starting (arguments, dependencies, source folder, etc.).
die() {
  print -u2 -r -- "Error: $*"
  exit 2
}

# ------------------------------------------------------------------------------
# 3. Temporary file cleanup
# ------------------------------------------------------------------------------

# Removes the temporary directory for the current conversion. If it fails, it
# stores the path so the EXIT routine can retry cleanup when the process ends.
remove_current_temp() {
  if [[ -n "$CURRENT_TMP_DIR" && ( -e "$CURRENT_TMP_DIR" || -L "$CURRENT_TMP_DIR" ) ]]; then
    if ! command rm -rf -- "$CURRENT_TMP_DIR" 2>/dev/null; then
      print -u2 -r -- "Warning: could not remove temporary directory: ${(q)CURRENT_TMP_DIR}"
      ORPHAN_TMP_DIRS+=("$CURRENT_TMP_DIR")
      (( TEMP_CLEANUP_ERRORS += 1 ))
    fi
  fi
  CURRENT_TMP=""
  CURRENT_TMP_DIR=""
}

# If the process exits normally or receives INT/TERM, it removes any temporary
# files it created. SIGKILL and abrupt shutdown cannot be caught; in those cases,
# a hidden temporary file may remain in the destination folder.
cleanup() {
  # Each conversion uses a dedicated temporary directory. It is removed entirely
  # to clean up both the temporary Markdown output and any helper files MarkItDown
  # may create during conversion.
  if [[ -n "$CURRENT_TMP_DIR" && ( -e "$CURRENT_TMP_DIR" || -L "$CURRENT_TMP_DIR" ) ]]; then
    command rm -rf -- "$CURRENT_TMP_DIR" 2>/dev/null || \
      print -u2 -r -- "Warning: could not remove temporary directory: ${(q)CURRENT_TMP_DIR}"
  fi

  # Retries removing temporaries whose first cleanup attempt failed.
  local orphan_tmp
  for orphan_tmp in "${ORPHAN_TMP_DIRS[@]}"; do
    command rm -rf -- "$orphan_tmp" 2>/dev/null || true
  done

  if [[ -n "$MANIFEST" && ( -e "$MANIFEST" || -L "$MANIFEST" ) ]]; then
    command rm -f -- "$MANIFEST" 2>/dev/null || true
  fi

  if [[ -n "$SORTED_MANIFEST" && ( -e "$SORTED_MANIFEST" || -L "$SORTED_MANIFEST" ) ]]; then
    command rm -f -- "$SORTED_MANIFEST" 2>/dev/null || true
  fi
}

# EXIT runs cleanup when the script exits. INT and TERM are converted to standard
# exit codes; cleanup will also run on exit.
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# ------------------------------------------------------------------------------
# 4. Argument normalization and source validation
# ------------------------------------------------------------------------------

# Only a single optional folder is accepted.
if (( $# > 1 )); then
  usage
  die "more than one argument was received."
fi

if (( $# == 1 )); then
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    *)
      SOURCE_ARG="$1"
      ;;
  esac
else
  SOURCE_ARG="."
fi

# Verifies that the path exists and is a directory. The directory change with -P
# resolves symlinks in the path and uses the real physical location.
if [[ ! -d "$SOURCE_ARG" ]]; then
  die "the path does not exist or is not a folder: ${(q)SOURCE_ARG}"
fi

builtin cd -P -- "$SOURCE_ARG" 2>/dev/null || \
  die "could not access the folder: ${(q)SOURCE_ARG}"

# PWD now contains the absolute source path. We avoid basename or command
# substitution to preserve special characters in names.
SOURCE_DIR="$PWD"

# The system root does not have a folder name. In that case, we use "root" so
# the destination becomes /root Markdown instead of an invalid path.
if [[ "$SOURCE_DIR" == "/" ]]; then
  SOURCE_NAME="root"
else
  SOURCE_NAME="${SOURCE_DIR:t}"
fi

if [[ "$SOURCE_DIR" == "/" ]]; then
  OUTPUT_ROOT="/${SOURCE_NAME} Markdown"
else
  OUTPUT_ROOT="${SOURCE_DIR}/${SOURCE_NAME} Markdown"
fi

# ------------------------------------------------------------------------------
# 5. Dependency checks
# ------------------------------------------------------------------------------

# markitdown must be available in the PATH for this Zsh session. This is
# especially important when running from a Python virtual environment.
command -v markitdown >/dev/null 2>&1 || \
  die "'markitdown' was not found in the PATH for this Zsh session."

# The following tools are used to traverse, sort, and safely write files. WSL
# usually provides the GNU versions.
for dependency in find sort mktemp mkdir mv rm cp; do
  command -v "$dependency" >/dev/null 2>&1 || \
    die "required dependency not found: $dependency"
done

# -print0 / sort -z and -samefile are needed to handle names with spaces,
# newlines, and special characters, and to exclude the output folder.
# This small test checks that sort accepts the NUL delimiter.
command sort -z </dev/null >/dev/null 2>&1 || \
  die "the 'sort' version does not support -z; GNU sort is required on WSL."

# ------------------------------------------------------------------------------
# 6. Output folder preparation and validation
# ------------------------------------------------------------------------------

# The output root is never allowed to be a symlink: it could point outside the
# source folder. If it already exists, it must be a real directory.
if [[ -L "$OUTPUT_ROOT" ]]; then
  die "the output folder is a symbolic link: ${(q)OUTPUT_ROOT}"
fi

if [[ -e "$OUTPUT_ROOT" && ! -d "$OUTPUT_ROOT" ]]; then
  die "the output path exists, but it is not a folder: ${(q)OUTPUT_ROOT}"
fi

# Creates only the root folder. We do not use mkdir -p across the full structure
# because we will validate directories one by one later to avoid traversing any
# symlinks that may already exist inside the output folder.
if [[ ! -d "$OUTPUT_ROOT" ]]; then
  command mkdir -- "$OUTPUT_ROOT" 2>/dev/null || \
    die "could not create the output folder: ${(q)OUTPUT_ROOT}"
fi

# A second check covers the uncommon case where another process changed the path
# between the initial check and creation.
[[ -d "$OUTPUT_ROOT" && ! -L "$OUTPUT_ROOT" ]] || \
  die "the output folder is not a safe directory: ${(q)OUTPUT_ROOT}"

# ------------------------------------------------------------------------------
# 7. Function to build and create the destination path for each folder
# ------------------------------------------------------------------------------

# Receives a folder from the original tree and prepares its equivalent folder
# inside OUTPUT_ROOT. It appends " Markdown" to each path component.
#
# Example:
#   SOURCE_DIR=/data/Project
#   source_path=/data/Project/Invoices/2026
#   result=/data/Project Markdown/Invoices Markdown/2026 Markdown
#
# The function validates each level before using it. If a destination folder is a
# symlink or a file, it refuses to continue through that path.
# It returns the final path in the REPLY variable with status 0 if everything is
# valid; it returns status 1 if it cannot prepare the folder.
ensure_destination_dir() {
  local source_path="$1"
  local relative_path
  local part
  local current="$OUTPUT_ROOT"
  local -a path_parts

  # Re-validates the destination root every time we use it.
  [[ ! -L "$current" && -d "$current" ]] || return 1

  # If the parent directory of a file is the source itself, OUTPUT_ROOT is enough.
  if [[ "$source_path" == "$SOURCE_DIR" ]]; then
    REPLY="$current"
    return 0
  fi

  # Calculates the relative path from the source. The root requires separate
  # handling because removing "/" differs from removing "source/".
  if [[ "$SOURCE_DIR" == "/" ]]; then
    relative_path="${source_path#/}"
  else
    relative_path="${source_path#"$SOURCE_DIR"/}"
  fi

  # Splits by path separators. Spaces and other characters in each component are
  # preserved; '/' cannot be part of a Linux filename.
  path_parts=("${(@s:/:)relative_path}")

  for part in "${path_parts[@]}"; do
    [[ -n "$part" ]] || continue
    current+="/${part} Markdown"

    # -L also catches broken symlinks, which -e alone does not detect.
    if [[ -L "$current" ]]; then
      return 1
    fi

    if [[ -e "$current" ]]; then
      # If it exists, it must be a real directory; we never accept a file here.
      [[ -d "$current" ]] || return 1
    else
      # Creates a single level. If another process creates it simultaneously, we
      # accept it only if it is now a real directory and not a symlink.
      if ! command mkdir -- "$current" 2>/dev/null; then
        [[ -d "$current" && ! -L "$current" ]] || return 1
      fi
    fi
  done

  REPLY="$current"
  return 0
}

# ------------------------------------------------------------------------------
# 8. Temporary manifest creation
# ------------------------------------------------------------------------------

# The manifest avoids traversing the folder twice while Markdown files are being
# created inside it. We store paths terminated in NUL instead of newlines because
# Linux filenames may contain '\n'.
MANIFEST="$(command mktemp "${TMPDIR:-/tmp}/markitdown-recursive.XXXXXXXX")" || \
  die "could not create the temporary manifest."

SORTED_MANIFEST="$(command mktemp "${TMPDIR:-/tmp}/markitdown-recursive-sorted.XXXXXXXX")" || \
  die "could not create the temporary sorted manifest."

# ------------------------------------------------------------------------------
# 9. Traversing the source tree
# ------------------------------------------------------------------------------

# -mindepth 1 prevents including the source folder itself.
# -name '.*' -prune excludes hidden files and directories. Pruning a hidden
# folder also excludes everything inside it.
# -samefile excludes the output Markdown folder and all of its contents, even if
# that folder already existed before the script ran. It also excludes the
# temporary manifests: TMPDIR could be inside the source tree itself (for example,
# when processing / or using a custom TMPDIR).
# -print0 allows storing paths with newlines or other unusual characters.
# We only inventory directories, regular files, symlinks, and special files;
# devices and FIFOs are never passed to MarkItDown.
command find "$SOURCE_DIR" -mindepth 1 \
  \( -name '.*' -o -samefile "$OUTPUT_ROOT" \
     -o -samefile "$MANIFEST" -o -samefile "$SORTED_MANIFEST" \) -prune -o \
  \( -type d -o -type f -o -type l -o -type p -o -type s -o -type b -o -type c \) \
  -print0 >| "$MANIFEST"
FIND_STATUS=$?

# If find encountered permission issues or another problem, it keeps the entries it
# found but records the error so the final exit status is non-zero. We do not
# pretend the traversal was complete.
TRAVERSAL_ERRORS=0
if (( FIND_STATUS != 0 )); then
  print -u2 -r -- "Warning: find could not fully traverse the source tree; it will process whatever it could locate."
  TRAVERSAL_ERRORS=1
fi

# Sorts entries using NUL as the delimiter and locale C. This ensures that when two
# files produce the same .md name, the same file always wins (the first in
# lexicographic order) instead of depending on the filesystem's variable physical
# delivery order.
LC_ALL=C command sort -z "$MANIFEST" -o "$SORTED_MANIFEST" || \
  die "could not sort the file manifest."

# ------------------------------------------------------------------------------
# 10. First pass: replicate visible folders
# ------------------------------------------------------------------------------

DIRECTORY_ERRORS=0

while IFS= read -r -d '' entry; do
  # Only real directories are replicated. Symlinked directories also appear in the
  # manifest, but they should neither be traversed nor replicated.
  if [[ -d "$entry" && ! -L "$entry" ]]; then
    if ! ensure_destination_dir "$entry"; then
      print -u2 -r -- "Error: could not create or validate the destination folder for: ${(q)entry}"
      (( DIRECTORY_ERRORS += 1 ))
    fi
  fi
done < "$SORTED_MANIFEST"

# ------------------------------------------------------------------------------
# 11. Counters and destination registry for this run
# ------------------------------------------------------------------------------

TOTAL_FILES=0
CONVERTED=0
FAILED=0
COPIED_MARKDOWN=0
SKIPPED_EXISTING=0
SKIPPED_COLLISIONS=0
SKIPPED_SYMLINKS=0
SKIPPED_SPECIAL=0

# Associative array in Zsh. It allows distinguishing a file that already existed
# before the run from a name collision caused by two files from the same source.
typeset -A GENERATED_DESTINATIONS

# ------------------------------------------------------------------------------
# 12. Second pass: convert regular files
# ------------------------------------------------------------------------------

while IFS= read -r -d '' source_file; do
  # Symbolic links are explicitly skipped. We do not follow links to other
  # directories or convert files referenced by symlinks.
  if [[ -L "$source_file" ]]; then
    print -r -- "Skipped (symbolic link): ${(q)source_file}"
    (( SKIPPED_SYMLINKS += 1 ))
    continue
  fi

  # Folders were already processed in the first pass.
  [[ -d "$source_file" ]] && continue

  # Prevents opening FIFOs, sockets, and devices: some may block indefinitely or
  # cause unintended reads/writes.
  if [[ ! -f "$source_file" ]]; then
    print -r -- "Skipped (not a regular file): ${(q)source_file}"
    (( SKIPPED_SPECIAL += 1 ))
    continue
  fi

  (( TOTAL_FILES += 1 ))

  # Extracts the final path component. Hidden files were already excluded by find,
  # but we keep the check here as extra protection.
  filename="${source_file:t}"
  if [[ "$filename" == .* ]]; then
    print -r -- "Skipped (hidden file): ${(q)source_file}"
    (( SKIPPED_SPECIAL += 1 ))
    continue
  fi

  # Existing .md files are already in the target format. They are copied without
  # going through MarkItDown so they also appear in the output tree; the final
  # extension is normalized to .md. The comparison is case-insensitive: .md, .MD,
  # and .Md are all treated as Markdown.
  lowercase_filename="${filename:l}"
  IS_MARKDOWN=0
  if [[ "$lowercase_filename" == *.md ]]; then
    IS_MARKDOWN=1
  fi

  # We do not attempt to convert a file the current session cannot read.
  if [[ ! -r "$source_file" ]]; then
    print -u2 -r -- "Error: no read permission: ${(q)source_file}"
    (( FAILED += 1 ))
    continue
  fi

  # Removes only the last extension:
  #   report.pdf       -> report.md
  #   data.v2.xlsx     -> data.v2.md
  #   file             -> file.md
  #   name.final.      -> name.final.md
  # Files starting with a dot were already excluded as hidden.
  if [[ "$filename" == *.* ]]; then
    stem="${filename%.*}"
    [[ -n "$stem" ]] || stem="$filename"
  else
    stem="$filename"
  fi

  # Finds or creates the Markdown folder corresponding to the parent directory.
  source_parent="${source_file:h}"
  if ! ensure_destination_dir "$source_parent"; then
    print -u2 -r -- "Error: could not prepare the destination folder for: ${(q)source_file}"
    (( FAILED += 1 ))
    continue
  fi
  destination_dir="$REPLY"
  destination_file="${destination_dir}/${stem}.md"

  # Checks the destination before converting. -L also detects broken symlinks.
  # A taken path is never overwritten.
  if [[ -e "$destination_file" || -L "$destination_file" ]]; then
    if (( ${+GENERATED_DESTINATIONS[$destination_file]} )); then
      print -r -- "Skipped (name collision): ${(q)source_file} -> ${(q)destination_file}"
      (( SKIPPED_COLLISIONS += 1 ))
    else
      print -r -- "Skipped (destination already exists): ${(q)destination_file}"
      (( SKIPPED_EXISTING += 1 ))
    fi
    continue
  fi

  # Creates a dedicated temporary directory inside the destination folder.
  # The output.md file does not exist yet, so we can verify that MarkItDown really
  # created it and avoid confusing an empty pre-created temporary with a valid result.
  # Since it is on the same filesystem as the destination, the final move of the file
  # can be atomic.
  CURRENT_TMP_DIR="$(command mktemp -d "${destination_dir}/.markitdown.XXXXXXXX")"
  if [[ -z "$CURRENT_TMP_DIR" || ! -d "$CURRENT_TMP_DIR" || -L "$CURRENT_TMP_DIR" ]]; then
    print -u2 -r -- "Error: could not create a temporary directory in: ${(q)destination_dir}"
    remove_current_temp
    (( FAILED += 1 ))
    continue
  fi
  CURRENT_TMP="${CURRENT_TMP_DIR}/output.md"

  if (( IS_MARKDOWN )); then
    # A .md file is already in the target format: it is copied byte-for-byte to
    # preserve the original content and keep it inside the output Markdown tree.
    print -r -- "Copying existing Markdown: ${(q)source_file}"
    if ! command cp -- "$source_file" "$CURRENT_TMP"; then
      print -u2 -r -- "Error: could not copy the existing Markdown file: ${(q)source_file}"
      remove_current_temp
      (( FAILED += 1 ))
      continue
    fi
  else
    # MarkItDown detects the file format from the source and writes the result to
    # the temporary file. We do not filter extensions: all visible regular files are
    # sent to the tool, which decides whether it can process them.
    print -r -- "Converting: ${(q)source_file}"
    if ! command markitdown "$source_file" -o "$CURRENT_TMP"; then
      print -u2 -r -- "Error: MarkItDown could not convert: ${(q)source_file}"
      remove_current_temp
      (( FAILED += 1 ))
      continue
    fi
  fi

  # A valid output must have been created by MarkItDown and must be a regular file,
  # not a directory or symlink. A zero-byte file is acceptable: some valid documents
  # may contain no extractable text.
  if [[ ! -f "$CURRENT_TMP" || -L "$CURRENT_TMP" ]]; then
    print -u2 -r -- "Error: MarkItDown did not produce a valid output file for: ${(q)source_file}"
    remove_current_temp
    (( FAILED += 1 ))
    continue
  fi

  # Publishes the temporary file without overwriting a destination that another
  # process may have created during conversion. -T prevents mv from treating the
  # destination as a directory; -n prevents overwriting an existing file (GNU coreutils).
  if command mv -nT -- "$CURRENT_TMP" "$destination_file"; then
    if [[ -e "$CURRENT_TMP" || -L "$CURRENT_TMP" ]]; then
      # mv -n did not move the file because the destination appeared in the meantime.
      if [[ -e "$destination_file" || -L "$destination_file" ]]; then
        print -r -- "Skipped (destination appeared during conversion): ${(q)destination_file}"
        (( SKIPPED_EXISTING += 1 ))
      else
        print -u2 -r -- "Error: could not place the result in: ${(q)destination_file}"
        (( FAILED += 1 ))
      fi
      remove_current_temp
    else
      # The file is only registered as converted if the temporary file disappeared
      # because it was moved to the final destination.
      GENERATED_DESTINATIONS[$destination_file]=1
      if (( IS_MARKDOWN )); then
        (( COPIED_MARKDOWN += 1 ))
      else
        (( CONVERTED += 1 ))
      fi
      # The file has already been moved; only the empty temporary directory remains.
      remove_current_temp
    fi
  else
    print -u2 -r -- "Error: could not save the result: ${(q)destination_file}"
    remove_current_temp
    (( FAILED += 1 ))
  fi

  # The temporary directory is already deleted or marked for retry.
done < "$SORTED_MANIFEST"

# ------------------------------------------------------------------------------
# 13. Final summary and exit code
# ------------------------------------------------------------------------------

print ""
print "================ Resumen de MarkItDown ================"
print -r -- "Source:                        ${(q)SOURCE_DIR}"
print -r -- "Destination:                   ${(q)OUTPUT_ROOT}"
print -r -- "Regular files found:           $TOTAL_FILES"
print -r -- "Successfully converted:        $CONVERTED"
print -r -- "Failed conversions:            $FAILED"
print -r -- "Existing Markdown copied:      $COPIED_MARKDOWN"
print -r -- "Skipped (destination exists):  $SKIPPED_EXISTING"
print -r -- "Skipped (name collision):      $SKIPPED_COLLISIONS"
print -r -- "Skipped symlinks:              $SKIPPED_SYMLINKS"
print -r -- "Skipped special files:         $SKIPPED_SPECIAL"
print -r -- "Folder creation errors:        $DIRECTORY_ERRORS"
print -r -- "Traversal errors:             $TRAVERSAL_ERRORS"
print -r -- "Temporary cleanup errors:      $TEMP_CLEANUP_ERRORS"
print "========================================================"

# A code of 0 means all processable data converted without errors.
# Code 1 indicates partial errors; code 2 is reserved for failures that prevent the
# execution from starting (validation or dependency issues).
if (( FAILED > 0 || DIRECTORY_ERRORS > 0 || TRAVERSAL_ERRORS > 0 || TEMP_CLEANUP_ERRORS > 0 )); then
  print -u2 -r -- "Process finished with errors. Review the messages above."
  exit 1
fi

print -r -- "Process finished successfully."
exit 0
