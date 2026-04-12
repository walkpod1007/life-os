#!/bin/bash
# claude-terminal.sh — 終端機互動 session，跑在 Life-OS 目錄，帶 watchdog + supervisor
# 用法：bash ~/Documents/Life-OS/scripts/claude-terminal.sh
# alias claude 已指向此腳本

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
WORK_DIR="$HOME/Documents/Life-OS"
LOG="$HOME/.claude/claude-terminal.log"
TMUX_TARGET="claude-terminal"
STOP_FLAG="$HOME/.claude/terminal-supervisor-stop"
RESTART_FLAG="$HOME/.claude/terminal-supervisor-restart"

BACKOFF=5
BACKOFF_MAX=300
FAIL_COUNT=0
FAIL_LIMIT=30
FAIL_RESET_SECS=1800
LAST_FAIL_TS=0
MIN_HEALTHY_SECS=60

SUPERVISOR_PID_FILE="$HOME/.claude/claude-terminal-supervisor.pid"

cd "$WORK_DIR" || exit 1
rm -f "$STOP_FLAG"
echo $$ > "$SUPERVISOR_PID_FILE"
trap 'rm -f "$SUPERVISOR_PID_FILE"' EXIT INT TERM

echo "$(date): claude-terminal supervisor 啟動 (PID $$)" >> "$LOG"

while true; do
  START_TS=$(date +%s)

  # Token watchdog (background) — 150k 觸發 session-end + 重啟
  bash "$HOME/Documents/Life-OS/scripts/token-watchdog.sh" "$TMUX_TARGET" &
  WATCHDOG_PID=$!

  echo "$(date): claude 啟動（watchdog PID $WATCHDOG_PID）" >> "$LOG"

  command claude "$@"
  EXIT_CODE=$?

  kill "$WATCHDOG_PID" 2>/dev/null
  END_TS=$(date +%s)
  RUNTIME=$((END_TS - START_TS))
  echo "$(date): claude 結束 (exit $EXIT_CODE, ran ${RUNTIME}s)" >> "$LOG"

  # 手動 /exit 或 stop flag → 不重啟
  if [ -f "$STOP_FLAG" ]; then
    echo "$(date): stop flag，停止 supervisor" >> "$LOG"
    rm -f "$STOP_FLAG"
    break
  fi

  # exit 0 = 使用者主動離開，詢問是否重啟
  if [ "$EXIT_CODE" -eq 0 ]; then
    echo ""
    echo "Claude session 結束。5 秒後自動重啟，按 Ctrl+C 取消..."
    sleep 5 || { echo "$(date): 使用者取消重啟" >> "$LOG"; break; }
  fi

  # Backoff logic
  NOW_TS=$(date +%s)
  if [ "$RUNTIME" -ge "$MIN_HEALTHY_SECS" ]; then
    BACKOFF=5
    FAIL_COUNT=0
    LAST_FAIL_TS=0
  elif [ -f "$RESTART_FLAG" ]; then
    # 主動重啟（token-watchdog / session-end 觸發）不計入 fast-fail
    echo "$(date): 主動重啟（RESTART_FLAG），不計 fast-fail (ran ${RUNTIME}s)" >> "$LOG"
    rm -f "$RESTART_FLAG"
    BACKOFF=5
    FAIL_COUNT=0
    LAST_FAIL_TS=0
  else
    if [ "$LAST_FAIL_TS" -gt 0 ] && [ $((NOW_TS - LAST_FAIL_TS)) -ge "$FAIL_RESET_SECS" ]; then
      echo "$(date): 冷卻期滿，fail count 歸零" >> "$LOG"
      FAIL_COUNT=0
      BACKOFF=5
    fi
    FAIL_COUNT=$((FAIL_COUNT + 1))
    LAST_FAIL_TS=$NOW_TS
    BACKOFF=$((BACKOFF * 2))
    if [ "$BACKOFF" -gt "$BACKOFF_MAX" ]; then
      BACKOFF=$BACKOFF_MAX
    fi
    echo "$(date): 快速失敗 #${FAIL_COUNT}/${FAIL_LIMIT} (ran ${RUNTIME}s)" >> "$LOG"
    if [ "$FAIL_COUNT" -ge "$FAIL_LIMIT" ]; then
      echo "$(date): 連續 ${FAIL_LIMIT} 次快速失敗，supervisor 永久停止" >> "$LOG"
      break
    fi
  fi

  rm -f "$RESTART_FLAG"
  echo "$(date): ${BACKOFF}s 後重啟 (failures: ${FAIL_COUNT})..." >> "$LOG"
  sleep "$BACKOFF"
  stty sane 2>/dev/null
  echo "$(date): 重啟 claude..." >> "$LOG"
done
