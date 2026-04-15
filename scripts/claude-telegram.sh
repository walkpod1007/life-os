#!/bin/bash
TMUX_SESSION="claude-telegram"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
STOP_FLAG="$HOME/.claude/telegram-supervisor-stop"
RESTART_FLAG="$HOME/.claude/telegram-supervisor-restart"
WORK_DIR="$HOME/Documents/Life-OS"
LOG="$HOME/.claude/claude-telegram.log"

# Backoff settings
BACKOFF=5
BACKOFF_MAX=300
FAIL_COUNT=0
FAIL_LIMIT=30
FAIL_RESET_SECS=1800   # 30 分鐘無新失敗則歸零
LAST_FAIL_TS=0
MIN_HEALTHY_SECS=60

if [ -z "$TMUX" ]; then
  echo "$(date): 包進 tmux '$TMUX_SESSION'" >> "$LOG"
  tmux kill-session -t "$TMUX_SESSION" 2>/dev/null
  tmux new-session -d -s "$TMUX_SESSION" "bash $HOME/Documents/Life-OS/scripts/claude-telegram.sh"
  echo "$(date): tmux session 已建立" >> "$LOG"
  exit 0
fi

SUPERVISOR_PID_FILE="$HOME/.claude/claude-telegram-supervisor.pid"
echo $$ > "$SUPERVISOR_PID_FILE"
trap 'rm -f "$SUPERVISOR_PID_FILE"' EXIT INT TERM
echo "$(date): supervisor 在 tmux 內啟動 (PID $$)" >> "$LOG"
rm -f "$STOP_FLAG"

while true; do
  START_TS=$(date +%s)

  # Token watchdog (background) — 150k 自動重啟
  bash "$HOME/Documents/Life-OS/scripts/token-watchdog.sh" "claude-telegram" &
  WATCHDOG_PID=$!

  # 重啟後主動排水 — 不等 webhook 觸發才醒
  (
    sleep 10
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
      tmux send-keys -t "$TMUX_SESSION" "請呼叫 get_pending 讀取待處理的 Telegram 訊息並回覆。" Enter
      echo "$(date): auto-sent get_pending trigger" >> "$LOG"
    fi
  ) &
  TRIGGER_PID=$!

  cd "$WORK_DIR" && claude --model sonnet --strict-mcp-config --mcp-config "$WORK_DIR/config/mcp-life.json" 2>>"$LOG"
  EXIT_CODE=$?
  kill "$WATCHDOG_PID" "$TRIGGER_PID" 2>/dev/null
  END_TS=$(date +%s)
  RUNTIME=$((END_TS - START_TS))
  echo "$(date): claude 結束 (exit $EXIT_CODE, ran ${RUNTIME}s)" >> "$LOG"

  if [ -f "$STOP_FLAG" ]; then
    echo "$(date): stop flag，停止" >> "$LOG"
    rm -f "$STOP_FLAG"; exit 0
  fi

  # Backoff logic: reset on healthy run, escalate on rapid failure
  NOW_TS=$(date +%s)
  if [ "$RUNTIME" -ge "$MIN_HEALTHY_SECS" ]; then
    BACKOFF=5
    FAIL_COUNT=0
    LAST_FAIL_TS=0
  elif [ -f "$RESTART_FLAG" ]; then
    # 主動重啟（self-restart 觸發）不計入 fast-fail
    echo "$(date): 主動重啟（RESTART_FLAG），不計 fast-fail (ran ${RUNTIME}s)" >> "$LOG"
    rm -f "$RESTART_FLAG"
    BACKOFF=5
    FAIL_COUNT=0
    LAST_FAIL_TS=0
  else
    # 冷卻歸零：距上次失敗超過 30 分鐘
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
      exit 1
    fi
  fi

  rm -f "$RESTART_FLAG"
  echo "$(date): ${BACKOFF}s 後重啟 (failures: ${FAIL_COUNT})..." >> "$LOG"
  sleep "$BACKOFF"
  stty sane 2>/dev/null
  echo "$(date): 重啟 claude..." >> "$LOG"
  continue
done
