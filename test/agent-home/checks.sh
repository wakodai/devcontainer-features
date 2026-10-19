#!/bin/bash
# 各テストから読み込む共通の確認。dev-container-features-test-lib の check を使う。
# ホストのファイルは test/fixtures/make-fake-home.sh で作ったダミー。

LEAK="DO-NOT-""LEAK"

agent_home() {
  local target
  target=$(readlink "$HOME/.claude")
  echo "${target%/.claude}"
}

check_wiring() {
  local ah
  ah=$(agent_home)
  check "~/.claude はワークスペースの agent-home へのリンク" bash -c "[[ '$ah' == */.devcontainer/agent-home ]]"
  check "~/.claude.json もリンク" bash -c "[ \"\$(readlink $HOME/.claude.json)\" = '$ah/.claude.json' ]"
  check "~/.codex もリンク" bash -c "[ \"\$(readlink $HOME/.codex)\" = '$ah/.codex' ]"
  check "~/.agents もリンク" bash -c "[ \"\$(readlink $HOME/.agents)\" = '$ah/.agents' ]"
  check "agent-home は git の対象外" grep -qx '\*' "$ah/.gitignore"
}

check_host_files() {
  local ah
  ah=$(agent_home)
  check "ホストの CLAUDE.md が見える" grep -q "host CLAUDE.md" "$HOME/.claude/CLAUDE.md"
  check "相対リンクのスキルが読める" grep -q "demo skill" "$HOME/.claude/skills/demo/SKILL.md"
  check "~/.agents のスキルが読める" grep -q "demo skill" "$HOME/.agents/skills/demo/SKILL.md"
  check "ホストの AGENTS.md が見える" grep -q "host AGENTS.md" "$HOME/.codex/AGENTS.md"
  check "CLAUDE.md は読み取り専用" bash -c "! touch $HOME/.claude/CLAUDE.md 2>/dev/null"
  check "スキルは読み取り専用" bash -c "! touch $ah/.agents/new-file 2>/dev/null"
  check "settings.json はコピー（書き込める）" bash -c "[ -f $HOME/.claude/settings.json ] && [ ! -L $HOME/.claude/settings.json ] && [ -w $HOME/.claude/settings.json ]"
  check "ホストのログイン情報や会話ログは見えない" bash -c "! grep -rqs '$LEAK' /home /root /workspaces /etc /tmp"
}

check_mcp() {
  check "Codex に起動できる MCP サーバーが渡る" bash -c "grep -q 'mcp_servers.ctx' /etc/codex/config.toml && grep -q 'mcp_servers.deepwiki' /etc/codex/config.toml"
  check "Codex にアプリ専用・キー入りのサーバーは渡らない" bash -c "! grep -qE 'node_repl|with-key' /etc/codex/config.toml"
  check "Codex がシステム層の MCP サーバーを読む" bash -c "codex mcp list 2>/dev/null | grep -q ctx"
  check "Claude に起動できる MCP サーバーが渡る" \
    node -e 'const s = require(process.env.HOME + "/.claude.json").mcpServers; process.exit(s.ctx && s.web && !s["mac-only"] ? 0 : 1)'
  check "Claude のアカウント情報はホストから持ち込まない" bash -c "! grep -q someone@example.com $HOME/.claude.json"
}

check_plugins() {
  check "settings.json のプラグインが入る" grep -q '"document-skills@anthropic-agent-skills"' "$HOME/.claude/plugins/installed_plugins.json"
}
