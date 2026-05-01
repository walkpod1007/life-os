#!/bin/bash
# claude-remote.sh — remote-control session supervisor（手動啟動，auto /remote-control）
#
# 用途：手機 / Mac App 透過 /remote-control 連入的 session。
# 跟 claude-line 結構對稱。被 claude-line-supervisors-watchdog.sh 透過
# cron @reboot + */5 * * * * 自動拉起；可手動啟動補救。
#
# 啟動方式：
#   bash ~/Documents/life-os/scripts/claude-remote.sh
# 接入方式：
#   tmux attach -t claude-remote

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# 載入共用 supervisor guard（多因子 PID 驗證 + idempotent 重建）
source "$HOME/Documents/life-os/scripts/lib/supervisor-guard.sh"

TMUX_SESSION="claude-remote"
STOP_FLAG="$HOME/.claude/remote-supervisor-stop"
RESTART_FLAG="$HOME/.claude/remote-supervisor-restart"
REPO_ROOT="$HOME/Documents/life-os"
WORK_DIR="$REPO_ROOT/ws/remote"
LOG="$HOME/.claude/claude-remote.log"

BACKOFF=5
BACKOFF_MAX=300
FAIL_COUNT=0
FAIL_LIMIT=30
FAIL_RESET_SECS=1800
LAST_FAIL_TS=0
MIN_HEALTHY_SECS=60
REMOTE_CONTROL_DELAY=8   # 秒，等 claude CLI 就緒後自動 /remote-control

SUPERVISOR_PID_FILE="$HOME/.claude/claude-remote-supervisor.pid"

# 巢狀 supervisor 防護：非 --inner 走 wrap_or_skip，--inner 才跑 supervisor loop
if [ "${1:-}" != "--inner" ]; then
  supervisor_wrap_or_skip "$TMUX_SESSION" "$SUPERVISOR_PID_FILE" "$HOME/Documents/life-os/scripts/claude-remote.sh" "$LOG"
  exit 0
fi
# Singleton guard（多因子：PID + start_time + tmux session）
if supervisor_is_healthy "$SUPERVISOR_PID_FILE" "$TMUX_SESSION"; then
  OLD_PID="$(cut -d'|' -f1 "$SUPERVISOR_PID_FILE" 2>/dev/null)"
  if [ "$OLD_PID" != "$$" ]; then
    echo "$(date): remote supervisor already running (PID $OLD_PID), aborting" >> "$LOG"
    exit 1
  fi
fi
supervisor_pid_write "$SUPERVISOR_PID_FILE" "$$" "$TMUX_SESSION"
WATCHDOG_PID=""
supervisor_install_trap WATCHDOG_PID "$SUPERVISOR_PID_FILE"
echo "$(date): remote supervisor started inside tmux (PID $$)" >> "$LOG"
rm -f "$STOP_FLAG"

while true; do
  START_TS=$(date +%s)

  # 殺掉上一輪殘留 watchdog（如果還活著）— 防止雙 watchdog 殭屍（Bug #1）
  if [ -n "${WATCHDOG_PID:-}" ] && kill -0 "$WATCHDOG_PID" 2>/dev/null; then
    kill "$WATCHDOG_PID" 2>/dev/null || true
    # 等最多 3 秒讓它優雅退出
    for _ in 1 2 3; do kill -0 "$WATCHDOG_PID" 2>/dev/null || break; sleep 1; done
    kill -KILL "$WATCHDOG_PID" 2>/dev/null || true
  fi

  # Token watchdog (background) — 200k 自動重啟
  WATCHDOG_NO_PERMISSION_ESCAPE=1 bash "$HOME/Documents/life-os/scripts/token-watchdog.sh" "claude-remote" &
  WATCHDOG_PID=$!

  # Auto /remote-control：偵測 prompt 就緒（出現 ❯ 字元）再送，最多等 60 秒
  (
    WAITED=0
    while [ $WAITED -lt 60 ]; do
      sleep 2
      WAITED=$((WAITED + 2))
      if tmux capture-pane -t "$TMUX_SESSION" -p 2>/dev/null | grep -q '❯'; then
        sleep 1  # 額外緩衝確保 CLI ready
        tmux send-keys -t "$TMUX_SESSION" "/remote-control" Enter
        echo "$(date): auto-sent /remote-control (prompt ready after ${WAITED}s)" >> "$LOG"
        break
      fi
    done
    if [ $WAITED -ge 60 ]; then
      echo "$(date): /remote-control auto-send timeout (60s), prompt never appeared" >> "$LOG"
    fi
  ) &
  REMOTE_PID=$!

  echo "$(date): CWD before claude: $(cd "$WORK_DIR" && pwd)" >> "$LOG"
  # 2026-04-20 翻卡：remote 升級成全能救命稻草，對齊 termi 規格
  # - model: opus-4-7（原 sonnet）
  # - MCP: 讀全域 ~/.claude.json（移除 --strict-mcp-config / --mcp-config）
  # - memory: ws/remote/memory 已 symlink 到 ws/terminal/memory
  cd "$WORK_DIR" && claude --model claude-opus-4-7 --permission-mode auto --remote-control-session-name-prefix applyao
  EXIT_CODE=$?
  kill "$WATCHDOG_PID" 2>/dev/null
  kill "$REMOTE_PID" 2>/dev/null
  END_TS=$(date +%s)
  RUNTIME=$((END_TS - START_TS))
  echo "$(date): claude-remote exited (exit $EXIT_CODE, ran ${RUNTIME}s)" >> "$LOG"

  supervisor_backoff_tick "$START_TS" "$END_TS" "$STOP_FLAG" "$RESTART_FLAG"
  TICK_RC=$?
  if [ "$TICK_RC" -eq 2 ]; then
    echo "$(date): stop flag detected, stopping" >> "$LOG"
    rm -f "$STOP_FLAG"; exit 0
  elif [ "$TICK_RC" -eq 1 ]; then
    echo "$(date): ${FAIL_LIMIT} consecutive fast fails, stopping permanently" >> "$LOG"
    exit 1
  fi
  # rc=0 → continue with backoff sleep
  echo "$(date): fast fail #${FAIL_COUNT}/${FAIL_LIMIT} (ran ${RUNTIME}s), restarting in ${BACKOFF}s..." >> "$LOG"
  rm -f "$RESTART_FLAG"
  sleep "$BACKOFF"
  stty sane 2>/dev/null
  echo "$(date): restarting claude-remote..." >> "$LOG"
  continue
done
