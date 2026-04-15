#!/bin/bash
# claude-line-note.sh — LINE-note session supervisor with auto-restart.
# Routes 阿普筆記群 (Cad539...) messages to an independent session with lightweight tools.

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
TMUX_SESSION="claude-line-note"
STOP_FLAG="$HOME/.claude/line-note-supervisor-stop"
RESTART_FLAG="$HOME/.claude/line-note-supervisor-restart"
WORK_DIR="$HOME/Documents/Life-OS"
LOG="$HOME/.claude/claude-line-note.log"

BACKOFF=5
BACKOFF_MAX=300
FAIL_COUNT=0
FAIL_LIMIT=30
FAIL_RESET_SECS=1800
LAST_FAIL_TS=0
MIN_HEALTHY_SECS=60

# 巢狀 supervisor 防護：禁止從 tmux pane 內部建立第二個 supervisor
if [ -n "$TMUX" ]; then
  _CURRENT_SESSION=$(tmux display-message -p '#S' 2>/dev/null)
  if [ "$_CURRENT_SESSION" = "$TMUX_SESSION" ]; then
    echo "ERROR: 已在 tmux session '$TMUX_SESSION' 內部，拒絕建立巢狀 supervisor。" >&2
    echo "若要重啟，請用 self-restart.sh 或從 tmux 外部執行。" >&2
    exit 1
  fi
  unset _CURRENT_SESSION
fi

if [ -z "$TMUX" ]; then
  echo "$(date): wrapping into tmux '$TMUX_SESSION'" >> "$LOG"
  tmux kill-session -t "$TMUX_SESSION" 2>/dev/null
  tmux new-session -d -s "$TMUX_SESSION" "bash $HOME/Documents/Life-OS/scripts/claude-line-note.sh"
  echo "$(date): tmux session created" >> "$LOG"
  exit 0
fi

SUPERVISOR_PID_FILE="$HOME/.claude/claude-line-note-supervisor.pid"
echo $$ > "$SUPERVISOR_PID_FILE"
trap 'rm -f "$SUPERVISOR_PID_FILE"' EXIT INT TERM
echo "$(date): line-note supervisor started inside tmux (PID $$)" >> "$LOG"
rm -f "$STOP_FLAG"

while true; do
  START_TS=$(date +%s)

  # Token watchdog (background) — 150k 自動重啟
  bash "$HOME/Documents/Life-OS/scripts/token-watchdog.sh" "claude-line-note" &
  WATCHDOG_PID=$!

  # 重啟後主動排水 — 不等 webhook 觸發才醒
  (
    sleep 25
    for i in 1 2 3; do
      PANE_NOW=$(tmux capture-pane -t "$TMUX_SESSION" -p 2>/dev/null | tail -3)
      if echo "$PANE_NOW" | grep -q "❯"; then break; fi
      sleep 5
    done
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
      tmux send-keys -t "$TMUX_SESSION" "請呼叫 get_pending 讀取待處理的 LINE 訊息並回覆。" Enter
      echo "$(date): auto-sent get_pending trigger" >> "$LOG"
    fi
  ) &
  TRIGGER_PID=$!

  cd "$WORK_DIR" && claude --model sonnet --strict-mcp-config --mcp-config "$WORK_DIR/config/mcp-line-note.json" --settings '{"enableAllProjectMcpServers":false,"enabledMcpjsonServers":[]}'
  EXIT_CODE=$?
  kill "$WATCHDOG_PID" "$TRIGGER_PID" 2>/dev/null
  END_TS=$(date +%s)
  RUNTIME=$((END_TS - START_TS))
  echo "$(date): claude-line-note exited (exit $EXIT_CODE, ran ${RUNTIME}s)" >> "$LOG"

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
  echo "$(date): restarting claude-line-note..." >> "$LOG"
  continue
done
