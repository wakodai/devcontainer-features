#!/bin/bash
# root 以外のユーザー（vscode）で動かす
set -e

# shellcheck source=/dev/null
source dev-container-features-test-lib
# shellcheck source=checks.sh
source "$(dirname "$0")/checks.sh"

check "root 以外で動いている" bash -c "[ \"\$(id -un)\" = vscode ]"
check_wiring
check_host_files
check_mcp
check_plugins

reportResults
