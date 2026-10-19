# Tool from GitHub Releases（gh-release-tool）

GitHub のリリースにあるコマンドを、devcontainer に入れる Feature です。リリースはコンテナの `gh` のログインで取ってくるので、private リポジトリのツールにも使えます。本体と、指定したディレクトリ（ログイン情報の保存先など）はホストの `~/.config/gh-release-tool` に置くので、一度取ってくれば、そのホストの全部の devcontainer で使え、リビルドしても残ります。

## 使い方

```jsonc
{
    "dev.containers.defaultFeatures": {
        "ghcr.io/wakodai/devcontainer-features/gh-release-tool:0": {
            "repo": "example-org/example-cli",
            "command": "example-cli",
            "asset": "example-cli_linux_{arch}.tar.gz",
            "persistDirs": ".cache/example-cli",
            "stableMachineId": true
        }
    }
}
```

各ホストで一度だけ、次のことをします。

1. ホストでディレクトリを作る（ないとコンテナが起動しません）。

    ```sh
    mkdir -p ~/.config/gh-release-tool && chmod 700 ~/.config/gh-release-tool
    ```

2. コンテナのターミナルで GitHub にログインし、コンテナを再起動する。private リポジトリの場合は、そのリポジトリを読めるアカウントでログインしてください。gh のログインをコンテナ間で共有する Feature と一緒に使うと、ログインは1回で済みます。

    ```sh
    gh auth login
    ```

## オプション

| オプション | 既定値 | 説明 |
|---|---|---|
| `repo` | （必須） | リリースを取るリポジトリ（`owner/name`） |
| `command` | （必須） | コマンド名。`/usr/local/bin` にこの名前で置く。アーカイブ（`.tar.gz`、`.tgz`、`.tar.xz`、`.zip`）なら、中からこの名前のファイルを探す |
| `asset` | （必須） | リリースのファイル名。`{arch}` は `amd64` / `arm64` に置き換える |
| `version` | `latest` | タグ（例: `v1.2.3`）。`latest` のときは、まだ入っていなければ最新版を入れる。入っていれば取り直さない |
| `persistDirs` | （なし） | ホストに置いて共有する、ホームからの相対パス（カンマ区切り）。ログイン情報の保存先などを指定する |
| `stableMachineId` | `false` | コンテナのマシン ID（`/var/lib/dbus/machine-id`）を、ホストごとに固定の値にする |

必須のオプションがない、または形が正しくないときは、警告だけを出して何もしません（`defaultFeatures` に入れると全部のコンテナに入るので、ビルドを止めないようにしています）。

`latest` のまま新しい版に上げたいときは、ホストの `~/.config/gh-release-tool/<command>/bin/` を消してからコンテナを再起動してください。

## 仕組み

ホストの `~/.config/gh-release-tool` を、コンテナの `/var/gh-release-tool` にマウントします。

```
/var/gh-release-tool/
  machine-id                              固定のマシン ID（stableMachineId のとき）
  <command>/bin/linux-<CPU>/<command>     本体。/usr/local/bin/<command> はここへのリンク
  <command>/data/<persistDirs の各パス>   ホームの同じパスはここへのリンク
```

- **本体を起動時に取ってくる理由：** private リポジトリのリリースは、イメージのビルド時には認証なしで取れません。トークンを Feature のオプションで渡すと、設定ファイルに平文で残ります。そこで起動時に、コンテナの gh のログインで取ってきます。
- **stableMachineId がある理由：** マシン ID を鍵にしてログイン情報を暗号化するコマンドがあります。コンテナのマシン ID はイメージのビルドごとに変わるか存在しないので、そのままではリビルドするとログイン情報を読めなくなります。

## 制限と注意

- 1つのコンテナに入れられるコマンドは1つだけです（同じ Feature は1つの設定に1回しか書けないため）。
- コマンドを取ってくるまでは、`/usr/local/bin/<command>` はリンク切れです。同じ名前のコマンドがイメージにあると、それが見えなくなります。
- `stableMachineId` は、コンテナの `/var/lib/dbus/machine-id` を固定の値に置き換えます。マシン ID を使うほかのソフトウェアにも、同じ値が見えます。
- マシン ID と暗号化したログイン情報を同じディレクトリに置くので、暗号化は保護として働きません。ディレクトリは自分だけが読めるように（`chmod 700`）しておいてください。
