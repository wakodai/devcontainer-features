#!/bin/sh
# gh-release-tool のインストール（イメージのビルド時に root で実行される）。
#
# private リポジトリのリリースは、ビルド時には認証なしで取れない。そこでビルド時はオプションを保存して
# リンクを作るだけにし、本体は起動時に start.sh がコンテナの gh のログインで取ってくる。
# 本体はホストのディレクトリ（/var/gh-release-tool にマウント）に置くので、一度取れば全部のコンテナで使える。
#
# オプションが足りない・おかしいときは警告だけにして何もしない（defaultFeatures で全部のコンテナに入るので、
# ビルドを止めると関係ないプロジェクトまで止まるため）。
set -eu

here=$(cd "$(dirname "$0")" && pwd)
lib=/usr/local/share/gh-release-tool
dir=/var/gh-release-tool

repo="${REPO:-}"
command="${COMMAND:-}"
asset="${ASSET:-}"
version="${VERSION:-latest}"
persist_dirs="${PERSISTDIRS:-}"
stable_machine_id="${STABLEMACHINEID:-false}"

warn() { echo "gh-release-tool: 警告: $*" >&2; }

# シェルで読み戻せるように、値を単一引用符で囲む
quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

enabled=1
if ! printf '%s' "$repo" | grep -qE '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$'; then
  warn "repo（owner/name）の指定がないか、形が正しくないので、何もしません"
  enabled=0
elif ! printf '%s' "$command" | grep -qE '^[A-Za-z0-9._-]+$'; then
  warn "command の指定がないか、使えない文字を含むので、何もしません"
  enabled=0
elif [ -z "$asset" ] || printf '%s' "$asset" | grep -q /; then
  warn "asset の指定がないか、/ を含むので、何もしません"
  enabled=0
fi
for p in $(printf '%s' "$persist_dirs" | tr ',' ' '); do
  case "$p" in
    /* | .. | ../* | */.. | */../*)
      warn "persistDirs はホームからの相対パスで、.. を含まないものにしてください: $p"
      enabled=0
      ;;
  esac
done

case "$(uname -m)" in
  x86_64 | amd64) arch=amd64 ;;
  aarch64 | arm64) arch=arm64 ;;
  *)
    warn "対応していない CPU です: $(uname -m)"
    enabled=0
    arch=unknown
    ;;
esac

mkdir -p "$lib"
install -m 755 "$here/scripts/start.sh" "$lib/"
{
  echo "ENABLED=$enabled"
  echo "REPO=$(quote "$repo")"
  echo "COMMAND=$(quote "$command")"
  echo "ASSET=$(quote "$asset")"
  echo "VERSION=$(quote "$version")"
  echo "PERSIST_DIRS=$(quote "$persist_dirs")"
  echo "STABLE_MACHINE_ID=$(quote "$stable_machine_id")"
  echo "ARCH=$(quote "$arch")"
} >"$lib/config"

[ "$enabled" = 1 ] || exit 0

# 本体はホストのディレクトリに置くので、そこへのリンクにしておく（起動時に取ってくるまではリンク切れ）
ln -sfn "$dir/$command/bin/linux-$arch/$command" "/usr/local/bin/$command"

# マシン ID でログイン情報を暗号化するコマンドのために、マシン ID をホストごとの固定値にする。
# コンテナのマシン ID はイメージのビルドごとに変わるか存在しないので、そのままではリビルドすると
# 保存したログイン情報を読めなくなる。/var/lib/dbus/machine-id は /etc/machine-id より先に読まれることが多い
if [ "$stable_machine_id" = true ]; then
  mkdir -p /var/lib/dbus
  if [ -e /var/lib/dbus/machine-id ] && [ ! -L /var/lib/dbus/machine-id ]; then
    mv /var/lib/dbus/machine-id /var/lib/dbus/machine-id.orig
  fi
  ln -sfn "$dir/machine-id" /var/lib/dbus/machine-id
fi

echo "gh-release-tool: $command をインストールしました（本体は起動時に $repo から取得します）"
