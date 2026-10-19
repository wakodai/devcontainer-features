#!/bin/bash
# オプションの形が正しくないときは、ビルドを止めずに何もしない
set -e

# shellcheck source=/dev/null
source dev-container-features-test-lib

check "無効になっている" grep -qx 'ENABLED=0' /usr/local/share/gh-release-tool/config
check "リンクは作らない" bash -c '[ ! -e /usr/local/bin/yq ] && [ ! -L /usr/local/bin/yq ]'

reportResults
