#!/bin/bash
# claude-line.sh — LINE session supervisor with auto-restart.
# Mirrors claude-supervisor.sh but without 8h push reminder (LINE push costs quota).

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
TMUX_SESSION="claude-line"
STOP_FLAG="$HOME/.claude/line-supervisor-stop"
RESTART_FLAG="$HOME/.claude/line-supervisor-restart"
WORK_DIR="$HOME/Documents/Life-OS"
LOG="$HOME/.claude/claude-line.log"

BACKOFF=5
BACKOFF_MAX=300
FAIL_COUNT=0
FAIL_LIMIT=30
FAIL_RESET_SECS=1800
LAST_FAIL_TS=0
MIN_HEALTHY_SECS=60

if [ -z "$TMUX" ]; then
  echo "$(date): wrapping into tmux '$TMUX_SESSION'" >> "$LOG"
  tmux kill-session -t "$TMUX_SESSION" 2>/dev/null
  tmux new-session -d -s "$TMUX_SESSION" "bash $HOME/Documents/Life-OS/scripts/claude-line.sh"
  echo "$(date): tmux session created" >> "$LOG"
  exit 0
fi

SUPERVISOR_PID_FILE="$HOME/.claude/claude-line-supervisor.pid"
echo $$ > "$SUPERVISOR_PID_FILE"
trap 'rm -f "$SUPERVISOR_PID_FILE"' EXIT INT TERM
echo "$(date): line supervisor started inside tmux (PID $$)" >> "$LOG"
rm -f "$STOP_FLAG"

while true; do
  START_TS=$(date +%s)

  # Token watchdog (background) — 150k 自動重啟
  bash "$HOME/Documents/Life-OS/scripts/token-watchdog.sh" "claude-line" &
  WATCHDOG_PID=$!

  # 重啟後主動排水 — 不等 webhook 觸發才醒
  (
    sleep 25
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
      tmux send-keys -t "$TMUX_SESSION" "請呼叫 get_pending 讀取待處理的 LINE 訊息並回覆。" Enter
      echo "$(date): auto-sent get_pending trigger" >> "$LOG"
    fi
  ) &
  TRIGGER_PID=$!

  cd "$WORK_DIR" && claude --model sonnet --strict-mcp-config --mcp-config "$WORK_DIR/config/mcp-line.json" --settings '{"enableAllProjectMcpServers":false,"enabledMcpjsonServers":[]}'
  EXIT_CODE=$?
  kill "$WATCHDOG_PID" "$TRIGGER_PID" 2>/dev/null
  END_TS=$(date +%s)
  RUNTIME=$((END_TS - START_TS))
  echo "$(date): claude-line exited (exit $EXIT_CODE, ran ${RUNTIME}s)" >> "$LOG"

  if [ -f "$STOP_FLAG" ]; then
    echo "$(date): stop flag detected, stopping" >> "$LOG"
    rm -f "$STOP_FLAG"; exit 0
  fi

  NOW_TS=$(date +%s)
  if [ "$RUNTIME" -ge "$MIN_HEALTHY_SECS" ]; then
    BACKOFF=5
    FAIL_COUNT=0
    LAST_FAIL_TS=0
  elif [ -f "$RESTART_FLAG" ]; then
    # intentional restart via self-restart — skip fast-fail counting
    echo "$(date): intentional restart (RESTART_FLAG), skip fast-fail (ran ${RUNTIME}s)" >> "$LOG"
    rm -f "$RESTART_FLAG"
    BACKOFF=5
    FAIL_COUNT=0
    LAST_FAIL_TS=0
  else
    if [ "$LAST_FAIL_TS" -gt 0 ] && [ $((NOW_TS - LAST_FAIL_TS)) -ge "$FAIL_RESET_SECS" ]; then
      echo "$(date): cooldown elapsed, resetting fail count" >> "$LOG"
      FAIL_COUNT=0
      BACKOFF=5
    fi
    FAIL_COUNT=$((FAIL_COUNT + 1))
    LAST_FAIL_TS=$NOW_TS
    BACKOFF=$((BACKOFF * 2))
    if [ "$BACKOFF" -gt "$BACKOFF_MAX" ]; then
      BACKOFF=$BACKOFF_MAX
    fi
    echo "$(date): fast fail #${FAIL_COUNT}/${FAIL_LIMIT} (ran ${RUNTIME}s)" >> "$LOG"
    if [ "$FAIL_COUNT" -ge "$FAIL_LIMIT" ]; then
      echo "$(date): ${FAIL_LIMIT} consecutive fast fails, stopping permanently" >> "$LOG"
      exit 1
    fi
  fi

  rm -f "$RESTART_FLAG"
  echo "$(date): restarting in ${BACKOFF}s (failures: ${FAIL_COUNT})..." >> "$LOG"
  sleep "$BACKOFF"
  stty sane 2>/dev/null
  echo "$(date): restarting claude-line..." >> "$LOG"
  continue
done
