#!/bin/sh
# agent-home: コンテナを起動するたびに実行する（postStartCommand）。
#
#   1. ホストの settings.json をコピーし直す（Claude がプラグインの有効化などで書き換えるので、リンクではなくコピー）
#   2. settings.json の enabledPlugins にあるプラグインのうち、まだ入っていないものを入れる
#   3. ホストの MCP サーバーのうち、このコンテナで起動できるものだけを Claude と Codex に渡す
#
# ホストで設定を変えたときは、コンテナを再起動すれば反映される。
# どれかが失敗しても警告だけにして、コンテナの起動は止めない。
set -u

ws="${1:?ワークスペースのパスを渡してください}"
ah="$ws/.devcontainer/agent-home"
host="$ah/.host"
lib=/usr/local/share/agent-home

log() { echo "agent-home: $*"; }
warn() { echo "agent-home: 警告: $*" >&2; }

# init.sh が配線したか（プロジェクト側の設定を優先して手を引いた場合は何もしない）
wired() {
  [ -L "$HOME/$1" ] && [ "$(readlink "$HOME/$1")" = "$ah/$1" ]
}

install_plugins() {
  if ! command -v claude >/dev/null 2>&1; then
    warn "claude が見つからないため、プラグインを入れられません"
    return 0
  fi
  known="$ah/.claude/plugins/known_marketplaces.json"
  installed="$ah/.claude/plugins/installed_plugins.json"
  node "$lib/agent-home.cjs" plugins "$ah/.claude/settings.json" | while IFS='	' read -r kind name source; do
    case "$kind" in
      marketplace)
        grep -qF "\"$name\"" "$known" 2>/dev/null && continue
        log "マーケットプレースを追加します: $name（$source）"
        claude plugin marketplace add "$source" </dev/null || warn "マーケットプレース $name を追加できませんでした"
        ;;
      plugin)
        grep -qF "\"$name\":" "$installed" 2>/dev/null && continue
        log "プラグインを入れます: $name"
        claude plugin install "$name" </dev/null || warn "プラグイン $name を入れられませんでした"
        ;;
    esac
  done
}

if wired .claude; then
  if [ -f "$host/claude-settings.json" ]; then
    cp "$host/claude-settings.json" "$ah/.claude/settings.json" || warn "settings.json をコピーできませんでした"
  else
    warn "ホストの ~/.claude/settings.json が見えません"
  fi
  install_plugins
  node "$lib/agent-home.cjs" claude-mcp "$host/claude.json" "$ah/.claude.json" \
    || warn "Claude Code に MCP サーバーを渡せませんでした"
fi

if wired .codex; then
  node "$lib/agent-home.cjs" codex-mcp "$host/codex-config.toml" /etc/codex/config.toml \
    || warn "Codex に MCP サーバーを渡せませんでした"
fi

exit 0
