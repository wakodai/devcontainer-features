#!/bin/sh
# gh-release-tool: コンテナを起動するたびに実行する（postStartCommand）。
#
# ホストの ~/.config/gh-release-tool（/var/gh-release-tool にマウント）に、次のものを置いて全部のコンテナで共有する。
#   machine-id                              固定のマシン ID（stableMachineId のとき）
#   <command>/data/<persistDirs の各パス>   ホームの同じパスはここへのリンク（ログイン情報の保存先など）
#   <command>/bin/linux-<CPU>/<command>     本体。なければコンテナの gh のログインで取ってくる
#
# どれかが失敗しても警告だけにして、コンテナの起動は止めない。
set -u

lib=/usr/local/share/gh-release-tool
dir=/var/gh-release-tool
# shellcheck source=/dev/null
. "$lib/config"
[ "$ENABLED" = 1 ] || exit 0

tool="$dir/$COMMAND"
bin="$tool/bin/linux-$ARCH"

log() { echo "gh-release-tool: $*"; }
warn() { echo "gh-release-tool: 警告: $*" >&2; }

if [ ! -w "$dir" ]; then
  warn "$dir に書き込めません。ホストに ~/.config/gh-release-tool があり、自分の所有になっているか確認してください"
  exit 0
fi

# 1. 固定のマシン ID
if [ "$STABLE_MACHINE_ID" = true ] && [ ! -s "$dir/machine-id" ]; then
  od -An -N16 -tx1 /dev/urandom | tr -d ' \n' >"$dir/machine-id"
  echo >>"$dir/machine-id"
  chmod 600 "$dir/machine-id"
fi

# 2. ホストに置いて共有するディレクトリ。ホームの同じパスはそこへのリンクにする（既存のものは退避する）
for rel in $(printf '%s' "$PERSIST_DIRS" | tr ',' ' '); do
  target="$tool/data/$rel"
  link="$HOME/$rel"
  mkdir -p "$target" "$(dirname "$link")"
  if [ -L "$link" ]; then
    [ "$(readlink "$link")" = "$target" ] || ln -sfn "$target" "$link"
    continue
  fi
  if [ -e "$link" ]; then
    mv "$link" "$link.gh-release-tool-backup-$(date +%Y%m%d%H%M%S)"
  fi
  ln -s "$target" "$link"
done

# 3. 本体。latest のときは、すでにあれば取り直さない。タグを指定したときは、違っていれば取り直す
download() {
  if ! command -v gh >/dev/null 2>&1; then
    warn "gh がないため、$COMMAND を取ってこられません"
    return 0
  fi
  if ! gh auth status >/dev/null 2>&1; then
    warn "$COMMAND を取ってくるには gh のログインが要ります。コンテナのターミナルで gh auth login を実行してから、コンテナを再起動してください"
    return 0
  fi
  tag=""
  if [ "$VERSION" = latest ]; then
    tag=$(gh release view -R "$REPO" --json tagName -q .tagName 2>/dev/null) || tag=""
  else
    tag="$VERSION"
  fi
  name=$(printf '%s' "$ASSET" | sed "s/{arch}/$ARCH/g")
  tmp=$(mktemp -d)
  # tag が空なら最新版を取る（引数ごと渡さない）
  # shellcheck disable=SC2086
  if ! gh release download $tag -R "$REPO" -p "$name" -D "$tmp" >/dev/null 2>&1; then
    warn "$REPO のリリースから $name を取ってこられませんでした（リポジトリにアクセスできるアカウントか確認してください）"
    rm -r "$tmp"
    return 0
  fi
  case "$name" in
    *.tar.gz | *.tgz) tar -xzf "$tmp/$name" -C "$tmp" ;;
    *.tar.xz) tar -xJf "$tmp/$name" -C "$tmp" ;;
    *.zip) (cd "$tmp" && unzip -q "$name") ;;
  esac
  # アーカイブなら中から command と同じ名前のファイルを探す。そうでなければ、取ってきたファイルそのもの
  found=$(find "$tmp" -type f -name "$COMMAND" | head -n 1)
  [ -n "$found" ] || found="$tmp/$name"
  mkdir -p "$bin"
  if install -m 755 "$found" "$bin/$COMMAND"; then
    echo "$tag" >"$bin/VERSION"
    log "$COMMAND ${tag:-（最新版）} を入れました"
  else
    warn "$COMMAND を置けませんでした"
  fi
  rm -r "$tmp"
}

if [ ! -x "$bin/$COMMAND" ]; then
  download
elif [ "$VERSION" != latest ] && [ "$(cat "$bin/VERSION" 2>/dev/null)" != "$VERSION" ]; then
  download
fi

exit 0
