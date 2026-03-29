#!/bin/bash
# telegram-watchdog.sh
# 偵測新 Telegram 訊息，若 Claude 未在跑則自動喚醒
# cron: * * * * * bash ~/.claude/telegram-watchdog.sh

ENV_FILE="$HOME/.claude/channels/telegram/.env"
LOG="$HOME/.claude/supervisor.log"
SUPERVISOR="$HOME/Documents/Life-OS/scripts/claude-supervisor.sh"
OFFSET_FILE="$HOME/.claude/channels/telegram/.tg_offset"
LAST_ACTIVE_FILE="$HOME/.claude/channels/telegram/.last_active"

# Claude CLI 在跑 → 更新活動時間，不搶 API，直接退出
CLAUDE_RUNNING=$(ps aux | grep -c "[c]laude-supervisor\|[c]laude")
if [ "$CLAUDE_RUNNING" -gt "0" ]; then
  date +%s > "$LAST_ACTIVE_FILE"
  exit 0
fi

# Claude/supervisor 沒在跑 → 輪詢 Telegram API
BOT_TOKEN=$(grep "TELEGRAM_BOT_TOKEN" "$ENV_FILE" 2>/dev/null | cut -d= -f2)
if [ -z "$BOT_TOKEN" ]; then exit 0; fi

OFFSET=0
if [ -f "$OFFSET_FILE" ]; then
  OFFSET=$(cat "$OFFSET_FILE")
fi

NEW_OFFSET=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?offset=${OFFSET}&limit=5&timeout=0" | \
  python3 -c "
import sys, json
d = json.load(sys.stdin)
results = d.get('result', [])
if results:
    print(results[-1]['update_id'] + 1)
" 2>/dev/null)

if [ -z "$NEW_OFFSET" ]; then
  exit 0  # 沒有新訊息
fi

# 有新訊息，更新 offset 和活動時間
echo "$NEW_OFFSET" > "$OFFSET_FILE"
date +%s > "$LAST_ACTIVE_FILE"

echo "$(date): telegram-watchdog 偵測到新訊息，喚醒 Claude" >> "$LOG"
nohup bash "$SUPERVISOR" >> "$LOG" 2>&1 &
