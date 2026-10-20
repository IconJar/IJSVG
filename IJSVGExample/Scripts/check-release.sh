#!/bin/sh
#
#  check release.sh
#  IJSVGExample
#
#  Created by Curtis Hard on 12/10/2026.
#  Copyright © 2026 Curtis Hard. All rights reserved.
#

# Check formatting, then validate a fresh consumer build of the package.
set -eu

repository_root="$(cd "$(dirname "$0")/../.." && pwd)"
/bin/bash "$repository_root/IJSVGExample/Scripts/check-format.sh"

scratch_directory="$(mktemp -d "${TMPDIR:-/tmp}/ijsvg-release.XXXXXX")"
trap 'rm -rf "$scratch_directory"' EXIT
trap 'exit 1' HUP INT TERM

xcrun swift test \
    --package-path "$repository_root" \
    --scratch-path "$scratch_directory" \
    --configuration release
