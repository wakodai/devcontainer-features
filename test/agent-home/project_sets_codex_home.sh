#!/bin/bash
# プロジェクトが CODEX_HOME を設定している場合、Codex には手を出さない
set -e

# shellcheck source=/dev/null
source dev-container-features-test-lib

check "~/.codex はリンクにしていない" bash -c "[ ! -L $HOME/.codex ]"
check "Claude Code は配線されている" bash -c "[[ \"\$(readlink $HOME/.claude)\" == */.devcontainer/agent-home/.claude ]]"

reportResults
