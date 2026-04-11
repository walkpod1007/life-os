#!/bin/bash
# bootstrap-channels.sh — 一鍵恢復 LINE + Telegram channels
# 用途：系統癱掉時跑這個，把所有 channel 拉回可用狀態
# 安全：只讀檢查 + 啟動服務，不會覆寫任何設定檔

set -uo pipefail

LIFE_OS="$HOME/Documents/Life-OS"
CLAUDE_DIR="$HOME/.claude"
CHANNELS_DIR="$CLAUDE_DIR/channels"
LOG="$CLAUDE_DIR/bootstrap-channels.log"

# 顏色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; ERRORS=$((ERRORS + 1)); }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
log()  { echo "$(date): $1" >> "$LOG"; }

ERRORS=0

echo ""
echo "═══ bootstrap-channels.sh ═══"
echo ""
log "bootstrap 開始"

# ──────────────────────────────────────────
# 1. 前置工具
# ──────────────────────────────────────────
echo "── 1. 前置工具 ──"

if command -v bun >/dev/null 2>&1; then
  ok "bun $(bun --version 2>/dev/null)"
else
  fail "bun 未安裝 → curl -fsSL https://bun.sh/install | bash"
fi

if command -v tmux >/dev/null 2>&1; then
  ok "tmux"
else
  fail "tmux 未安裝 → brew install tmux"
fi

if command -v claude >/dev/null 2>&1; then
  ok "claude CLI"
else
  fail "claude CLI 未安裝"
fi

# ──────────────────────────────────────────
# 2. LINE channel 檢查
# ──────────────────────────────────────────
echo ""
echo "── 2. LINE channel ──"

LINE_ENV="$CHANNELS_DIR/line/.env"
if [ -f "$LINE_ENV" ]; then
  if grep -q "LINE_CHANNEL_ACCESS_TOKEN=" "$LINE_ENV" && grep -q "LINE_CHANNEL_SECRET=" "$LINE_ENV"; then
    ok "LINE .env（TOKEN + SECRET 都在）"
  else
    if ! grep -q "LINE_CHANNEL_SECRET=" "$LINE_ENV"; then
      fail "LINE .env 缺少 LINE_CHANNEL_SECRET"
    fi
    if ! grep -q "LINE_CHANNEL_ACCESS_TOKEN=" "$LINE_ENV"; then
      fail "LINE .env 缺少 LINE_CHANNEL_ACCESS_TOKEN"
    fi
  fi
else
  fail "LINE .env 不存在 → $LINE_ENV"
fi

# LINE webhook (launchd)
LOBSTER_PLIST="com.lifeos.line-lobster"
if launchctl list 2>/dev/null | grep -q "$LOBSTER_PLIST"; then
  ok "LINE webhook launchd agent 已載入"
else
  warn "LINE webhook launchd agent 未載入，嘗試載入..."
  PLIST_FILE="$HOME/Library/LaunchAgents/${LOBSTER_PLIST}.plist"
  if [ -f "$PLIST_FILE" ]; then
    launchctl load "$PLIST_FILE" 2>/dev/null && ok "launchd agent 載入成功" || fail "launchd agent 載入失敗"
  else
    fail "plist 檔案不存在 → $PLIST_FILE"
  fi
fi

# LINE webhook health
HEALTH=$(curl -s --connect-timeout 3 http://localhost:3001/health 2>/dev/null || echo "")
if [ -n "$HEALTH" ] && echo "$HEALTH" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if d.get('status')=='ok' else 1)" 2>/dev/null; then
  PENDING=$(echo "$HEALTH" | python3 -c "import sys,json; print(json.load(sys.stdin).get('pending',0))" 2>/dev/null || echo "?")
  ok "LINE webhook 存活（pending: ${PENDING}）"
else
  fail "LINE webhook 沒回應（port 3001）"
fi

# LINE MCP server 原始碼
LINE_SERVER="$LIFE_OS/plugins/line-lobster/server.ts"
if [ -f "$LINE_SERVER" ]; then
  ok "line-lobster server.ts 存在"
else
  fail "line-lobster server.ts 遺失 → git checkout plugins/line-lobster/"
fi

# claude-line tmux session
echo ""
echo "── 3. claude-line session ──"

if tmux has-session -t "claude-line" 2>/dev/null; then
  ok "claude-line tmux session 存在"
  # 檢查裡面是否有 claude 進程
  CLAUDE_LINE_PID=$(pgrep -f "claude.*plugin:line" 2>/dev/null | head -1)
  if [ -n "$CLAUDE_LINE_PID" ]; then
    ok "claude-line 進程運行中 (PID $CLAUDE_LINE_PID)"
  else
    warn "claude-line tmux 存在但 claude 進程不在，嘗試重啟..."
    bash "$LIFE_OS/scripts/claude-line.sh" &
    sleep 3
    if tmux has-session -t "claude-line" 2>/dev/null; then
      ok "claude-line 重啟成功"
    else
      fail "claude-line 重啟失敗"
    fi
  fi
else
  warn "claude-line tmux session 不存在，啟動中..."
  log "啟動 claude-line supervisor"
  bash "$LIFE_OS/scripts/claude-line.sh" &
  sleep 3
  if tmux has-session -t "claude-line" 2>/dev/null; then
    ok "claude-line 啟動成功"
    log "claude-line 啟動成功"
  else
    fail "claude-line 啟動失敗"
    log "claude-line 啟動失敗"
  fi
fi

# ──────────────────────────────────────────
# 4. Telegram channel 檢查
# ──────────────────────────────────────────
echo ""
echo "── 4. Telegram channel ──"

TG_ENV="$CHANNELS_DIR/telegram/.env"
if [ -f "$TG_ENV" ]; then
  if grep -q "TELEGRAM_BOT_TOKEN=" "$TG_ENV"; then
    ok "Telegram .env（BOT_TOKEN 在）"
  else
    fail "Telegram .env 缺少 TELEGRAM_BOT_TOKEN"
  fi
else
  fail "Telegram .env 不存在 → $TG_ENV"
fi

TG_ACCESS="$CHANNELS_DIR/telegram/access.json"
if [ -f "$TG_ACCESS" ]; then
  ALLOW_COUNT=$(python3 -c "import json; print(len(json.load(open('$TG_ACCESS')).get('allowFrom',[])))" 2>/dev/null || echo 0)
  if [ "$ALLOW_COUNT" -gt 0 ]; then
    ok "Telegram access.json（$ALLOW_COUNT 個已配對用戶）"
  else
    warn "Telegram access.json 存在但 allowFrom 是空的（需要重新配對）"
  fi
else
  warn "Telegram access.json 不存在（首次使用需配對）"
fi

# Telegram plugin 狀態
TG_PLUGIN_STATUS=$(claude plugins list 2>/dev/null | grep -A2 "telegram@claude-plugins-official")
if echo "$TG_PLUGIN_STATUS" | grep -q "enabled"; then
  ok "telegram plugin 已啟用"
elif echo "$TG_PLUGIN_STATUS" | grep -q "telegram"; then
  warn "telegram plugin 已安裝但未啟用 → 在 Claude Code session 裡跑: /plugin enable telegram@claude-plugins-official"
else
  warn "telegram plugin 未安裝 → 在 Claude Code session 裡跑: /plugin install telegram@claude-plugins-official"
fi

# Telegram 跑在 claude-telegram session
echo ""
echo "── 5. claude-telegram session（Telegram bot 後端）──"

if tmux has-session -t "claude-telegram" 2>/dev/null; then
  ok "claude-telegram tmux session 存在"
  CLAUDE_TG_PID=$(pgrep -f "claude.*telegram-lobster" 2>/dev/null | head -1)
  if [ -n "$CLAUDE_TG_PID" ]; then
    ok "claude-telegram 進程運行中 (PID $CLAUDE_TG_PID)"
  else
    warn "claude-telegram tmux 存在但 claude 進程不在"
    echo "     → 手動啟動: bash $LIFE_OS/scripts/claude-telegram.sh"
  fi
else
  warn "claude-telegram tmux session 不存在"
  echo "     → 手動啟動: bash $LIFE_OS/scripts/claude-telegram.sh"
fi

# ──────────────────────────────────────────
# 6. 設定檔完整性
# ──────────────────────────────────────────
echo ""
echo "── 6. 設定檔完整性 ──"

SETTINGS="$CLAUDE_DIR/settings.json"
if [ -f "$SETTINGS" ] && python3 -c "import json; json.load(open('$SETTINGS'))" 2>/dev/null; then
  ok "settings.json 可解析"
else
  fail "settings.json 損壞或不存在"
fi

# 檢查 LINE MCP 權限是否在 settings 裡
if grep -q "mcp__line-lobster__get_pending" "$SETTINGS" 2>/dev/null; then
  ok "settings.json 包含 line-lobster 權限"
else
  warn "settings.json 缺少 line-lobster 權限（LINE 可能需要手動授權）"
fi

if grep -q "mcp__plugin_telegram_telegram__reply" "$SETTINGS" 2>/dev/null; then
  ok "settings.json 包含 telegram 權限"
else
  warn "settings.json 缺少 telegram 權限"
fi

# ──────────────────────────────────────────
# 7. Git 備份狀態
# ──────────────────────────────────────────
echo ""
echo "── 7. Git 備份狀態 ──"

cd "$LIFE_OS" 2>/dev/null
if git diff --quiet plugins/ 2>/dev/null; then
  ok "plugins/ 沒有未提交的變更"
else
  CHANGED=$(git diff --name-only plugins/ 2>/dev/null | wc -l | tr -d ' ')
  warn "plugins/ 有 $CHANGED 個未提交的變更 → git add plugins/ && git commit"
fi

UNTRACKED=$(git ls-files --others --exclude-standard plugins/ 2>/dev/null | wc -l | tr -d ' ')
if [ "$UNTRACKED" -gt 0 ]; then
  warn "plugins/ 有 $UNTRACKED 個未追蹤的檔案"
fi

AHEAD=$(git rev-list --count @{upstream}..HEAD 2>/dev/null || echo "?")
if [ "$AHEAD" = "0" ]; then
  ok "已推送到 remote"
elif [ "$AHEAD" = "?" ]; then
  warn "無法判斷 remote 狀態"
else
  warn "本地領先 remote $AHEAD 個 commit → git push"
fi

# ──────────────────────────────────────────
# 結果
# ──────────────────────────────────────────
echo ""
echo "═══════════════════════════════"
if [ "$ERRORS" -eq 0 ]; then
  echo -e "  ${GREEN}全部通過${NC} — channels 應該都能正常運作"
else
  echo -e "  ${RED}有 $ERRORS 項失敗${NC} — 請修復上面標 ✗ 的項目"
fi
echo ""
log "bootstrap 結束，errors=$ERRORS"
