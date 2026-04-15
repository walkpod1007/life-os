#!/bin/bash
# claude-remote.sh — remote-control session supervisor（手動啟動，auto /remote-control）
#
# 用途：手機 / Mac App 透過 /remote-control 連入的 session。
# 跟 claude-telegram / claude-line 結構對稱。手動啟動、不掛 cron。
#
# 啟動方式：
#   bash ~/Documents/Life-OS/scripts/claude-remote.sh
# 接入方式：
#   tmux attach -t claude-remote

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
TMUX_SESSION="claude-remote"
STOP_FLAG="$HOME/.claude/remote-supervisor-stop"
RESTART_FLAG="$HOME/.claude/remote-supervisor-restart"
WORK_DIR="$HOME/Documents/Life-OS"
LOG="$HOME/.claude/claude-remote.log"
MCP_CONFIG="$WORK_DIR/config/mcp-plan.json"

BACKOFF=5
BACKOFF_MAX=300
FAIL_COUNT=0
FAIL_LIMIT=30
FAIL_RESET_SECS=1800
LAST_FAIL_TS=0
MIN_HEALTHY_SECS=60
REMOTE_CONTROL_DELAY=8   # 秒，等 claude CLI 就緒後自動 /remote-control

# 巢狀 supervisor 防護：禁止從任何 tmux pane 內部執行（避免 supervisor 跑進錯誤 session）
if [ -n "$TMUX" ]; then
  echo "ERROR: 在 tmux 內部執行 supervisor 腳本會建立巢狀或錯位的 supervisor。" >&2
  echo "請從 tmux 外部執行，或使用 self-restart.sh 重啟。" >&2
  exit 1
fi

if [ -z "$TMUX" ]; then
  echo "$(date): wrapping into tmux '$TMUX_SESSION'" >> "$LOG"
  tmux kill-session -t "$TMUX_SESSION" 2>/dev/null
  tmux new-session -d -s "$TMUX_SESSION" "bash $HOME/Documents/Life-OS/scripts/claude-remote.sh"
  echo "$(date): tmux session created" >> "$LOG"
  echo "claude-remote session 已啟動。接入：tmux attach -t claude-remote"
  exit 0
fi

SUPERVISOR_PID_FILE="$HOME/.claude/claude-remote-supervisor.pid"
echo $$ > "$SUPERVISOR_PID_FILE"
trap 'rm -f "$SUPERVISOR_PID_FILE"' EXIT INT TERM
echo "$(date): remote supervisor started inside tmux (PID $$)" >> "$LOG"
rm -f "$STOP_FLAG"

while true; do
  START_TS=$(date +%s)

  # Token watchdog (background) — 150k 自動重啟
  bash "$HOME/Documents/Life-OS/scripts/token-watchdog.sh" "claude-remote" &
  WATCHDOG_PID=$!

  # Auto /remote-control：背景延遲送，等 claude CLI 就緒
  (
    sleep "$REMOTE_CONTROL_DELAY"
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
      tmux send-keys -t "$TMUX_SESSION" "/remote-control" Enter
      echo "$(date): auto-sent /remote-control" >> "$LOG"
    fi
  ) &
  REMOTE_PID=$!

  cd "$WORK_DIR" && claude --model sonnet --strict-mcp-config --mcp-config "$MCP_CONFIG"
  EXIT_CODE=$?
  kill "$WATCHDOG_PID" 2>/dev/null
  kill "$REMOTE_PID" 2>/dev/null
  END_TS=$(date +%s)
  RUNTIME=$((END_TS - START_TS))
  echo "$(date): claude-remote exited (exit $EXIT_CODE, ran ${RUNTIME}s)" >> "$LOG"

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
  echo "$(date): restarting claude-remote..." >> "$LOG"
  continue
done
