#!/bin/sh
# テスト用のダミーのホームを作る。devcontainer の CLI を HOME=<このディレクトリ> で動かすと、
# Feature のマウント（${localEnv:HOME}/...）がここを指すので、本物の ~/.claude などに触れずに試せる。
#
#   test/fixtures/make-fake-home.sh <ディレクトリ>
#
# コンテナから見えてはいけないファイルには、目印の文字列（下の LEAK）を入れておく。
# テストのファイル自身に一致しないよう、目印は2つに分けて組み立てる。
set -eu

home="${1:?ダミーのホームのディレクトリを渡してください}"
LEAK="DO-NOT-""LEAK"

mkdir -p "$home/.claude/hooks" "$home/.claude/commands" "$home/.claude/skills" "$home/.claude/projects/host" \
  "$home/.agents/skills/demo" "$home/.codex" "$home/dummy-claude"

# コンテナに見せるもの
echo "host CLAUDE.md" >"$home/.claude/CLAUDE.md"
printf '#!/bin/sh\necho statusline\n' >"$home/.claude/statusline-command.sh"
printf '#!/bin/sh\nexit 0\n' >"$home/.claude/hooks/sample.sh"
echo "# sample command" >"$home/.claude/commands/sample.md"
printf -- '---\nname: demo\ndescription: テスト用のスキル\n---\ndemo skill\n' >"$home/.agents/skills/demo/SKILL.md"
ln -sfn ../../.agents/skills/demo "$home/.claude/skills/demo"
echo "host AGENTS.md" >"$home/.codex/AGENTS.md"
cat >"$home/.claude/settings.json" <<'EOF'
{
  "enabledPlugins": {
    "document-skills@anthropic-agent-skills": true
  },
  "extraKnownMarketplaces": {
    "anthropic-agent-skills": {
      "source": { "source": "github", "repo": "anthropics/skills" }
    }
  },
  "hooks": {
    "Stop": [
      { "hooks": [ { "type": "command", "command": "[ -x ~/.local/bin/chezmoi-sync ] && ~/.local/bin/chezmoi-sync hook claude || true" } ] }
    ]
  }
}
EOF
cat >"$home/.claude.json" <<'EOF'
{
  "oauthAccount": { "emailAddress": "someone@example.com" },
  "mcpServers": {
    "ctx": { "type": "stdio", "command": "npx", "args": ["-y", "@upstash/context7-mcp@latest"] },
    "web": { "type": "http", "url": "https://mcp.deepwiki.com/mcp" },
    "mac-only": { "type": "stdio", "command": "/Applications/Nope.app/server" }
  }
}
EOF
cat >"$home/.codex/config.toml" <<'EOF'
model = "host-model"
notify = ["/Applications/ChatGPT.app/notify"]

[projects."/Users/someone/project"]
trust_level = "trusted"

[mcp_servers.ctx]
command = "npx"
args = ["-y", "@upstash/context7-mcp@latest"]

[mcp_servers.deepwiki]
url = "https://mcp.deepwiki.com/mcp"

[mcp_servers.node_repl]
command = "/Applications/ChatGPT.app/Contents/Resources/node_repl"

[mcp_servers.with-key]
command = "npx"
args = ["-y", "some-server"]

[mcp_servers.with-key.env]
SOME_API_KEY = "dummy"
EOF

# コンテナから見えてはいけないもの
echo "{\"claudeAiOauth\": \"$LEAK\"}" >"$home/.claude/.credentials.json"
echo "$LEAK" >"$home/.claude/projects/host/session.jsonl"
echo "{\"tokens\": \"$LEAK\"}" >"$home/.codex/auth.json"

# プロジェクトが自分で ~/.claude をマウントしている場合の試験用
echo "keep" >"$home/dummy-claude/marker"

echo "ダミーのホームを作りました: $home"
