#!/bin/sh
# Validate the package as a consumer builds it, without cached build products.
set -eu

repository_root="$(cd "$(dirname "$0")/../.." && pwd)"
scratch_directory="$(mktemp -d "${TMPDIR:-/tmp}/ijsvg-release.XXXXXX")"
trap 'rm -rf "$scratch_directory"' EXIT
trap 'exit 1' HUP INT TERM

xcrun swift test \
    --package-path "$repository_root" \
    --scratch-path "$scratch_directory" \
    --configuration release
