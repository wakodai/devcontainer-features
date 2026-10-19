#!/bin/bash
# プロジェクトが自分で ~/.claude をマウントしている場合、Claude Code には手を出さない
set -e

# shellcheck source=/dev/null
source dev-container-features-test-lib

check "~/.claude はリンクに置き換わっていない" bash -c "[ -d $HOME/.claude ] && [ ! -L $HOME/.claude ]"
check "プロジェクトがマウントした中身が残っている" grep -qx keep "$HOME/.claude/marker"
check "退避もしていない" bash -c "! ls -d $HOME/.claude.agent-home-backup-* 2>/dev/null"
check "Codex は配線されている" bash -c "[[ \"\$(readlink $HOME/.codex)\" == */.devcontainer/agent-home/.codex ]]"

reportResults
