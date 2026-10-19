#!/bin/bash
# 既定のテスト（オプションなし）。何も指定しなければ、ビルドを止めずに何もしない
set -e

# shellcheck source=/dev/null
source dev-container-features-test-lib

check "オプションがないときは無効になっている" grep -qx 'ENABLED=0' /usr/local/share/gh-release-tool/config
check "起動時の処理はエラーにならない" /usr/local/share/gh-release-tool/start.sh
check "gh は入っている" bash -c 'command -v gh'

reportResults
