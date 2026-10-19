#!/bin/sh
# agent-home: コンテナを作ったあとに1回だけ実行する（postCreateCommand）。
#
# <ワークスペース>/.devcontainer/agent-home/ にホームと同じ並びを作り、
# ~/.claude、~/.claude.json、~/.codex、~/.agents をそこへのリンクにする。
# ホストの設定は、devcontainer-feature.json のマウントで、この中に読み取り専用で見えている。
# ログイン情報やプラグイン、会話ログなどの状態もここに書かれるので、リビルドしても残り、ホストからも読める。
#
# プロジェクトが自分で ~/.claude などをマウントしている場合や、CLAUDE_CONFIG_DIR / CODEX_HOME を
# 設定している場合は、そのエージェントには手を出さない。rm -rf は使わず、既存のものは mv で退避する
# （マウントポイントは mv できずに失敗するので、ホストの中身を消すことはない）。
set -eu

ws="${1:?ワークスペースのパスを渡してください}"
ah="$ws/.devcontainer/agent-home"

log() { echo "agent-home: $*"; }
warn() { echo "agent-home: 警告: $*" >&2; }

# $1 がマウントポイントか（/proc/self/mountinfo の5番目の欄。空白などは \040 のように8進でエスケープされている）
is_mountpoint() {
  awk -v p="$1" '{ t = $5; gsub(/\\040/, " ", t); gsub(/\\011/, "\t", t); if (t == p) found = 1 } END { exit !found }' \
    /proc/self/mountinfo
}

# Docker がマウント先の親として作ったディレクトリは、Linux のホストでは root の所有になる。
# 中に状態を書けるよう、ディレクトリ自体だけをコンテナのユーザーに直す（-R は使わない。マウントの中には触れない）
fix_owner() {
  [ -d "$1" ] || return 0
  [ "$(stat -c %u "$1")" = 0 ] || return 0
  [ "$(id -u)" = 0 ] && return 0
  sudo -n chown "$(id -u):$(id -g)" "$1" 2>/dev/null \
    || warn "$1 の所有者を直せませんでした（sudo がパスワードなしで使えません）"
}

# $1 に $2 へのリンクを置く。リンク以外のものがあれば退避する
link() {
  if [ -L "$1" ]; then
    [ "$(readlink "$1")" = "$2" ] || ln -sfn "$2" "$1"
    return 0
  fi
  if [ -e "$1" ]; then
    backup="$1.agent-home-backup-$(date +%Y%m%d%H%M%S)"
    mv "$1" "$backup"
    log "$1 を $backup に退避しました"
  fi
  ln -s "$2" "$1"
}

wire_claude() {
  if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then
    warn "CLAUDE_CONFIG_DIR が設定されているので、Claude Code には手を出しません"
    return 0
  fi
  for p in "$HOME/.claude" "$HOME/.claude.json"; do
    if is_mountpoint "$p"; then
      warn "$p はプロジェクト側でマウントされているので、Claude Code には手を出しません"
      return 0
    fi
  done
  mkdir -p "$ah/.claude"
  # Claude は ~/.claude.json を一時ファイルからの rename で書き換えるので、リンク先の実体を先に作っておく
  [ -e "$ah/.claude.json" ] || echo '{}' >"$ah/.claude.json"
  link "$HOME/.claude" "$ah/.claude"
  link "$HOME/.claude.json" "$ah/.claude.json"
  log "Claude Code の状態は $ah/.claude に保存されます"
}

wire_codex() {
  if [ -n "${CODEX_HOME:-}" ]; then
    warn "CODEX_HOME が設定されているので、Codex には手を出しません"
    return 0
  fi
  if is_mountpoint "$HOME/.codex"; then
    warn "$HOME/.codex はプロジェクト側でマウントされているので、Codex には手を出しません"
    return 0
  fi
  mkdir -p "$ah/.codex"
  link "$HOME/.codex" "$ah/.codex"
  log "Codex の状態は $ah/.codex に保存されます"
}

wire_agents() {
  if is_mountpoint "$HOME/.agents"; then
    warn "$HOME/.agents はプロジェクト側でマウントされているので、そのままにします"
    return 0
  fi
  link "$HOME/.agents" "$ah/.agents"
}

for d in "$ws/.devcontainer" "$ah" "$ah/.claude" "$ah/.codex" "$ah/.host"; do
  fix_owner "$d"
done

wire_claude
wire_codex
wire_agents

# agent-home/ 全体（この .gitignore 自身も含む）を git の対象外にする。リポジトリの .gitignore には触れない
[ -e "$ah/.gitignore" ] || printf '*\n' >"$ah/.gitignore"
