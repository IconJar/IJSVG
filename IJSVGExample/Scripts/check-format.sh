#!/bin/bash
#
#  check-format.sh
#  IJSVGExample
#
#  Created by Curtis Hard on 13/10/2026.
#  Copyright © 2026 Curtis Hard. All rights reserved.
#

# Check formatting or apply both formatting steps when requested.
set -euo pipefail

mode="${1:---check}"
if [[ "$#" -gt 1 || ( "$mode" != '--check' && "$mode" != '--fix' ) ]]; then
    echo 'Usage: check-format.sh [--check|--fix]' >&2
    exit 2
fi

repository_root="$(cd "$(dirname "$0")/../.." && pwd)"
formatter="$(xcrun --find clang-format)"
scratch_directory="$(mktemp -d "${TMPDIR:-/tmp}/ijsvg-format.XXXXXX")"
trap 'rm -rf "$scratch_directory"' EXIT
trap 'exit 1' HUP INT TERM

cd "$repository_root"
git ls-files -z --cached --others --exclude-standard --deduplicate \
    -- '*.c' '*.h' '*.m' '*.mm' '*.cc' '*.cpp' '*.hpp' \
    > "$scratch_directory/candidates"

# NUL delimiters preserve spaces and newlines in filenames. Skip deleted files
# and public header symlinks whose source files are checked separately.
file_count=0
while IFS= read -r -d '' source_file; do
    if [[ -f "$source_file" && ! -L "$source_file" ]]; then
        printf './%s\0' "$source_file" >> "$scratch_directory/files"
        file_count=$((file_count + 1))
    fi
done < "$scratch_directory/candidates"

if [[ "$file_count" -eq 0 ]]; then
    echo 'No C or Objective-C source files found.' >&2
    exit 1
fi

if [[ "$mode" == '--fix' ]]; then
    xargs -0 "$formatter" --style=file -i < "$scratch_directory/files"
    xargs -0 /usr/bin/perl "$repository_root/IJSVGExample/Scripts/comment-spacing.pl" --fix \
        < "$scratch_directory/files"
fi

failed=0
if ! xargs -0 "$formatter" --style=file --dry-run --Werror \
    < "$scratch_directory/files"; then
    failed=1
fi
if ! xargs -0 /usr/bin/perl "$repository_root/IJSVGExample/Scripts/comment-spacing.pl" --check \
    < "$scratch_directory/files"; then
    failed=1
fi
if [[ "$failed" -ne 0 ]]; then
    echo 'Formatting check failed. Run bash IJSVGExample/Scripts/format.sh from the repository root.' >&2
    exit 1
fi

echo "Formatting check passed for $file_count source/header files."
