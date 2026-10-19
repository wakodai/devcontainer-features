# Agent Home（Claude Code / Codex）

devcontainer の中の Claude Code と Codex に、ホストの設定を読み取り専用で見せる Feature です。ログイン情報・プラグイン・会話ログは、プロジェクトごとにワークスペースの中へ保存するので、コンテナをリビルドしても残り、ホストからも読めます。

## 使い方

全部の devcontainer に入れる場合は、VS Code のユーザー設定に書きます。

```jsonc
{
    "dev.containers.defaultFeatures": {
        "ghcr.io/wakodai/devcontainer-features/agent-home:0": {}
    }
}
```

Claude Code の CLI（`ghcr.io/anthropics/devcontainer-features/claude-code`）、Codex の CLI（`ghcr.io/thamaji/devcontainer-features/codex-cli`）、Node.js（`ghcr.io/devcontainers/features/node`）は、この Feature が依存として入れます。

ログインはプロジェクトごとに1回です。コンテナの中で、Claude Code は `/login`、Codex は `codex login --device-auth` を実行してください。ホストのログイン情報はコンテナに渡しません。

## ホストに必要なファイル

次のファイルとディレクトリを読み取り専用でマウントします。ホストにないと、コンテナが起動しません。

- `~/.claude/CLAUDE.md`、`~/.claude/settings.json`、`~/.claude/statusline-command.sh`
- `~/.claude/hooks/`、`~/.claude/commands/`、`~/.claude/skills/`
- `~/.claude.json`
- `~/.agents/`
- `~/.codex/AGENTS.md`、`~/.codex/config.toml`

## コンテナの中の構成

ホストのホームと同じ並びを、ワークスペースの中の `.devcontainer/agent-home/` に作ります。コンテナの `~/.claude`、`~/.claude.json`、`~/.codex`、`~/.agents` は、そこへのリンクです。

```
<ワークスペース>/.devcontainer/agent-home/
  .gitignore              中身は「*」だけ。agent-home/ 全体を git の対象外にする
  .claude/                ~/.claude のリンク先
    .credentials.json, plugins/, projects/（会話ログ）など   プロジェクトごとの状態
    settings.json         ホストの settings.json のコピー（起動のたびに上書き）
    CLAUDE.md, statusline-command.sh, hooks/, commands/, skills/   ホストから読み取り専用
  .claude.json            ~/.claude.json のリンク先（プロジェクトごと）
  .codex/                 ~/.codex のリンク先
    auth.json, sessions/（会話ログ）, config.toml（ユーザー層）など   プロジェクトごとの状態
    AGENTS.md             ホストから読み取り専用
  .agents/                ホストの ~/.agents（読み取り専用）。~/.agents のリンク先
  .host/                  コピーや取り出しの元にするホストのファイル（読み取り専用）
/etc/codex/config.toml    Codex のシステム層。ホストの MCP サーバーだけを書き出したもの
```

ホストの `~/.claude/skills/<名前>` が `../../.agents/skills/<名前>` への相対リンクでも、ホストと同じ並びなのでそのまま解決できます。

## 起動のたびにやること

- ホストの `settings.json` をコピーし直す。
- `settings.json` の `enabledPlugins` で有効なプラグインのうち、入っていないものを入れる（マーケットプレースは `extraKnownMarketplaces` から取る）。
- ホストの MCP サーバー（Claude Code は `~/.claude.json` の `mcpServers`、Codex は `config.toml` の `[mcp_servers]`）のうち、次のものを除いて渡す。
  - アプリが書き込むサーバー（`node_repl`、`computer-use`）
  - env やヘッダーに、キーらしき項目（KEY、TOKEN、SECRET など）があるサーバー
  - `command` で起動するのに、そのコマンドがコンテナにないサーバー

ホストで設定を変えたら、コンテナを再起動すると反映されます。ディレクトリ（`skills/`、`hooks/`、`commands/`、`~/.agents`）の変更はすぐ見えます。

## プロジェクトの設定を優先する場合

次の場合、そのエージェントには手を出しません。既存のものを消すこともありません（`rm -rf` は使わず、リンク以外のものがあれば `mv` で退避します）。

- プロジェクトの devcontainer.json が `~/.claude`、`~/.claude.json`、`~/.codex` をマウントしている
- プロジェクトが `CLAUDE_CONFIG_DIR` や `CODEX_HOME` を設定している

## 注意

- **mounts は仕様から外れた書き方をしている。** 読み取り専用にするため、`devcontainer-feature.json` の `mounts` を `readonly` 付きの文字列で書いています。仕様のスキーマは `mounts` をオブジェクト（`readonly` の欄なし）に限っているので、公開時のスキーマ検査を外しています。VS Code の Dev Containers 拡張と devcontainer CLI では動作を確認していますが、ほかのツールでは動かない可能性があります。
- **ストアはワークスペースの中にある。** Dockerfile に `COPY . .` があり、ビルドの対象がリポジトリ全体のプロジェクトでは、ログイン情報がイメージに入ることがあります。
- **ホストの `~/.claude.json` と `~/.codex/config.toml` はコンテナから読める。** MCP サーバーの定義にトークンを直書きしないでください（環境変数で渡してください）。
- **Docker が作る空のファイルがホストに残る。** マウント先として、空のファイルやディレクトリがホスト側の `agent-home/` に作られます。Linux のホストでは root の所有になるので、ディレクトリだけは初回に `sudo` でコンテナのユーザーに直します。
