#!/bin/bash
#
#  format.sh
#  IJSVGExample
#
#  Created by Curtis Hard on 13/10/2026.
#  Copyright © 2026 Curtis Hard. All rights reserved.
#

set -euo pipefail
/bin/bash "$(dirname "$0")/check-format.sh" --fix
