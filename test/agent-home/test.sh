#!/bin/bash
# 既定のテスト（オプションなし、ベースイメージの既定のユーザー）
set -e

# shellcheck source=/dev/null
source dev-container-features-test-lib
# shellcheck source=checks.sh
source "$(dirname "$0")/checks.sh"

check_wiring
check_host_files
check_mcp
check_plugins

reportResults
