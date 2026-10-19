#!/bin/sh
# agent-home のインストール（イメージのビルド時に root で実行される）。
# 実際の配線はホストのファイルがマウントされている実行時に行う（init.sh / start.sh）。
set -eu

here=$(cd "$(dirname "$0")" && pwd)
dest=/usr/local/share/agent-home

mkdir -p "$dest"
install -m 755 "$here/scripts/init.sh" "$here/scripts/start.sh" "$dest/"
install -m 644 "$here/scripts/agent-home.cjs" "$here/vendor/smol-toml.cjs" "$here/vendor/LICENSE-smol-toml" "$dest/"

# Codex のシステム層の設定。起動のたびに start.sh が、ホストの config.toml から MCP サーバーだけを書き出す。
# 実行時はコンテナのユーザーで書き込むので、そのユーザーの所有にしておく。
mkdir -p /etc/codex
[ -e /etc/codex/config.toml ] || : >/etc/codex/config.toml
chown "${_REMOTE_USER:-root}" /etc/codex/config.toml

echo "agent-home: インストールしました（$dest）"
