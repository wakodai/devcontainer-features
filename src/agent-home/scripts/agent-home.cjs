// agent-home の起動時の処理のうち、JSON と TOML を扱う部分（start.sh から呼ぶ）。
//
//   node agent-home.cjs plugins <settings.json>
//       入れるマーケットプレースとプラグインを「種類<TAB>名前<TAB>取得元」の形で出力する
//   node agent-home.cjs claude-mcp <ホストの .claude.json> <コンテナの .claude.json>
//       ホストの mcpServers のうち、このコンテナで使えるものだけをコンテナ側に入れる
//   node agent-home.cjs codex-mcp <ホストの config.toml> <書き出す config.toml>
//       ホストの [mcp_servers] のうち、このコンテナで使えるものだけを書き出す（Codex のシステム層）
//
// MCP サーバーを渡さないのは次のもの:
//   - アプリ（ChatGPT など）がホストに書き込むサーバー。ホストのアプリの場所を指している
//   - env やヘッダーにキーらしき項目があるサーバー。秘密をコンテナに持ち込まない
//   - command で起動するが、そのコマンドがコンテナにないサーバー
"use strict";

const fs = require("fs");
const path = require("path");
const toml = require("./smol-toml.cjs");

const APP_SERVERS = new Set(["node_repl", "computer-use"]);
const SECRET_KEY = /(key|token|secret|passw|credential|auth)/i;

function readText(file) {
  try {
    return fs.readFileSync(file, "utf8");
  } catch (e) {
    if (e.code === "ENOENT") return null;
    throw e;
  }
}

function readJson(file) {
  const text = readText(file);
  return text && text.trim() ? JSON.parse(text) : {};
}

function log(message) {
  console.error(`agent-home: ${message}`);
}

function runnable(command) {
  const isExecutable = (file) => {
    try {
      fs.accessSync(file, fs.constants.X_OK);
      return fs.statSync(file).isFile();
    } catch {
      return false;
    }
  };
  if (command.includes("/")) return isExecutable(path.resolve(command));
  return (process.env.PATH || "").split(":").some((dir) => dir && isExecutable(path.join(dir, command)));
}

function hasSecret(server) {
  for (const field of ["env", "headers", "http_headers"]) {
    const values = server[field];
    if (values && typeof values === "object" && Object.keys(values).some((k) => SECRET_KEY.test(k))) return true;
  }
  return "bearer_token" in server;
}

function pickServers(servers, agent) {
  const picked = {};
  for (const [name, server] of Object.entries(servers || {})) {
    let reason = null;
    if (APP_SERVERS.has(name)) reason = "アプリ専用のサーバー";
    else if (hasSecret(server)) reason = "キーらしき項目がある";
    else if (server.command && !runnable(server.command)) reason = `${server.command} がコンテナにない`;
    if (reason) {
      log(`${agent} の MCP サーバー ${name} は渡しません（${reason}）`);
      continue;
    }
    picked[name] = server;
  }
  return picked;
}

function plugins(settingsFile) {
  const settings = readJson(settingsFile);
  const markets = settings.extraKnownMarketplaces || {};
  const lines = [];
  for (const [name, market] of Object.entries(markets)) {
    const source = market && market.source;
    if (source && source.source === "github" && source.repo) lines.push(["marketplace", name, source.repo]);
    else if (source && source.source === "git" && source.url) lines.push(["marketplace", name, source.url]);
  }
  for (const [id, enabled] of Object.entries(settings.enabledPlugins || {})) {
    if (enabled !== true) continue;
    const market = id.split("@").pop();
    if (market === "claude-plugins-official" && !(market in markets)) {
      lines.push(["marketplace", market, "anthropics/claude-plugins-official"]);
    }
    lines.push(["plugin", id, ""]);
  }
  // マーケットプレースを先に追加する
  lines.sort((a, b) => (a[0] === b[0] ? 0 : a[0] === "marketplace" ? -1 : 1));
  for (const line of lines) console.log(line.join("\t"));
}

function claudeMcp(hostFile, containerFile) {
  const servers = pickServers(readJson(hostFile).mcpServers, "Claude Code");
  const config = readJson(containerFile);
  if (JSON.stringify(config.mcpServers || {}) === JSON.stringify(servers)) return;
  config.mcpServers = servers;
  // Claude と同じく、一時ファイルに書いてから rename する（途中で失敗しても壊れたファイルを残さない）
  const tmp = `${containerFile}.agent-home-${process.pid}`;
  fs.writeFileSync(tmp, JSON.stringify(config, null, 2) + "\n");
  fs.renameSync(tmp, containerFile);
}

function codexMcp(hostFile, outFile) {
  const text = readText(hostFile);
  const servers = pickServers(text ? toml.parse(text).mcp_servers : {}, "Codex");
  const header = "# agent-home がホストの ~/.codex/config.toml から MCP サーバーだけを書き出したもの。起動のたびに上書きされる\n";
  const body = Object.keys(servers).length ? "\n" + toml.stringify({ mcp_servers: servers }) + "\n" : "";
  // /etc/codex にはコンテナのユーザーが書けないので、rename ではなくファイルをそのまま書き換える
  fs.writeFileSync(outFile, header + body);
}

const [command, ...args] = process.argv.slice(2);
const commands = { plugins, "claude-mcp": claudeMcp, "codex-mcp": codexMcp };
if (!commands[command]) {
  console.error("使い方: node agent-home.cjs plugins|claude-mcp|codex-mcp ...");
  process.exit(2);
}
commands[command](...args);
