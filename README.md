# devcontainer-features

個人用の [Dev Container Features](https://containers.dev/implementors/features/) です。

| Feature | 説明 |
|---|---|
| [agent-home](src/agent-home) | devcontainer の中の Claude Code と Codex に、ホストの設定を読み取り専用で見せ、ログイン・プラグイン・会話ログをプロジェクトごとにワークスペースの中へ保存する |
| [gh-release-tool](src/gh-release-tool) | GitHub のリリースにあるコマンドを、コンテナの gh のログインで取ってきて入れる（private リポジトリにも使える）。本体とログイン情報はホストに置き、全部の devcontainer で共有する |

## テスト

ホストの設定の代わりにダミーのホームを作り、`HOME` を差し替えて実行します（本物の `~/.claude` などには触れません）。

```sh
test/fixtures/make-fake-home.sh /tmp/fakehome
HOME=/tmp/fakehome devcontainer features test --features agent-home \
  --base-image mcr.microsoft.com/devcontainers/base:ubuntu .
```

Docker Desktop for Mac では、`HOME` を差し替えると Docker の接続先の設定が見えなくなるので、`DOCKER_CONFIG=$HOME/.docker`（差し替える前のホーム）も指定してください。

## 公開

GitHub Actions の「Release dev container features」を手動で実行すると、`ghcr.io/wakodai/devcontainer-features/<id>` に公開されます。
