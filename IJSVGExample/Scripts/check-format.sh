#!/bin/bash
# Check C and Objective-C formatting without changing files.
set -euo pipefail

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
# and public-header symlinks whose source files are checked separately.
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

if ! xargs -0 "$formatter" --style=file --dry-run --Werror \
    < "$scratch_directory/files"; then
    echo 'Formatting check failed. Run xcrun clang-format -i on the reported files and commit the changes before releasing.' >&2
    exit 1
fi

echo "Formatting check passed for $file_count source/header files."
