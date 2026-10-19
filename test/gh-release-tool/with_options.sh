#!/bin/bash
# オプションを指定したとき。CI では gh にログインしていないので本体は取ってこられない。
# 配線（リンク、固定のマシン ID、共有するディレクトリ）と、取ってこられなくても起動を止めないことを確かめる。
set -e

# shellcheck source=/dev/null
source dev-container-features-test-lib

check "コマンドはホストのディレクトリの本体へのリンク" \
  bash -c '[[ "$(readlink /usr/local/bin/yq)" == /var/gh-release-tool/yq/bin/linux-*/yq ]]'
check "マシン ID はホストのディレクトリの固定値" \
  bash -c '[ "$(readlink /var/lib/dbus/machine-id)" = /var/gh-release-tool/machine-id ] && grep -qE "^[0-9a-f]{32}$" /var/lib/dbus/machine-id'
check "1つ目の共有ディレクトリ" \
  bash -c '[ "$(readlink "$HOME/.cache/example-tool")" = /var/gh-release-tool/yq/data/.cache/example-tool ]'
check "2つ目の共有ディレクトリ（カンマのあとの空白は無視する）" \
  bash -c '[ "$(readlink "$HOME/.config/example-tool")" = /var/gh-release-tool/yq/data/.config/example-tool ]'

reportResults
