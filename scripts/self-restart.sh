#!/bin/bash
# self-restart.sh — 讓 Claude 自行重啟（支援 telegram/line/remote 三條 session）
#
# 使用：
#   bash self-restart.sh [claude-telegram|claude-line|claude-remote]
#   無參數時預設 claude-telegram
#
# 流程：
#   1. lock：防止同一條 session 多個 self-restart 同時跑
#   2. 等 30 秒讓上游（token-watchdog / session-end）先完成 hook
#   3. 若 supervisor tmux session 不存在 → 啟動新 supervisor
#   4. 殺掉當前 claude 進程（透過 tmux pane_pid → 子進程定位）
#   5. supervisor while loop 自動重啟

TARGET="${1:-claude-telegram}"

case "$TARGET" in
  claude-telegram)
    SUPERVISOR="$HOME/Documents/Life-OS/scripts/claude-telegram.sh"
    RESTART_FLAG="$HOME/.claude/telegram-supervisor-restart"
    STOP_FLAG="$HOME/.claude/telegram-supervisor-stop"
    LOCK_FILE="$HOME/.claude/self-restart-telegram.lock"
    ;;
  claude-line)
    SUPERVISOR="$HOME/Documents/Life-OS/scripts/claude-line.sh"
    RESTART_FLAG="$HOME/.claude/line-supervisor-restart"
    STOP_FLAG="$HOME/.claude/line-supervisor-stop"
    LOCK_FILE="$HOME/.claude/self-restart-line.lock"
    ;;
  claude-remote)
    SUPERVISOR="$HOME/Documents/Life-OS/scripts/claude-remote.sh"
    RESTART_FLAG="$HOME/.claude/remote-supervisor-restart"
    STOP_FLAG="$HOME/.claude/remote-supervisor-stop"
    LOCK_FILE="$HOME/.claude/self-restart-remote.lock"
    ;;
  *)
    echo "self-restart.sh: 未知 target '$TARGET'，支援 claude-telegram|claude-line|claude-remote" >&2
    exit 2
    ;;
esac

LOG="$HOME/.claude/supervisor.log"
mkdir -p "$HOME/.claude"

# 1. 防止多個 self-restart 同時執行（per-session lock，mkdir atomic on macOS）
# 注意：macOS 無 flock 命令，用 mkdir 當 atomic lock。
LOCK_DIR="${LOCK_FILE}.d"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  # lock 夾已存在，檢查內含的 PID 是否還活著
  STALE_PID=$(cat "$LOCK_DIR/pid" 2>/dev/null || echo "")
  if [ -n "$STALE_PID" ] && kill -0 "$STALE_PID" 2>/dev/null; then
    echo "$(date): self-restart ($TARGET) 已有實例在跑 (PID $STALE_PID)，跳過" >> "$LOG"
    exit 0
  else
    # stale lock，清掉再搶一次
    echo "$(date): self-restart ($TARGET) 偵測到 stale lock（PID $STALE_PID 不存在），清除重試" >> "$LOG"
    rm -rf "$LOCK_DIR"
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
      echo "$(date): self-restart ($TARGET) 搶鎖失敗，跳過" >> "$LOG"
      exit 0
    fi
  fi
fi
echo $$ > "$LOCK_DIR/pid"
trap 'rm -rf "$LOCK_DIR"' EXIT INT TERM

echo "$(date): self-restart ($TARGET) 觸發 (lock PID $$)" >> "$LOG"

# 2. 等 30 秒（呼叫方已先處理 hook）
echo "$(date): [$TARGET] 等待 30 秒..." >> "$LOG"
sleep 30

# 3. 建立重啟旗標
touch "$RESTART_FLAG"
rm -f "$STOP_FLAG"

# 4. 確認 supervisor tmux session 存在
if ! tmux -L default has-session -t "$TARGET" 2>/dev/null; then
  echo "$(date): [$TARGET] ⚠️ tmux session 不存在，啟動新 supervisor" >> "$LOG"
  rm -f "$RESTART_FLAG"
  bash "$SUPERVISOR" &
  sleep 3
  echo "$(date): [$TARGET] 新 supervisor 已啟動" >> "$LOG"
  exit 0
fi

# 5. 殺掉當前 claude 進程
# 注意：claude CLI 啟動後會改寫 argv，ps 只看得到 "claude" 沒有 flags，
# 所以不能靠 --mcp-config 檔名當 pgrep marker。改用 tmux pane_pid → ppid 樹定位：
# pane_pid 就是 pane 裡的 supervisor bash，claude 是它的直接 child。
PANE_PID=$(tmux -L default list-panes -t "$TARGET" -F '#{pane_pid}' 2>/dev/null | head -1)
if [ -z "$PANE_PID" ]; then
  echo "$(date): [$TARGET] 找不到 tmux pane_pid，supervisor loop 會自行重啟" >> "$LOG"
  exit 0
fi

CLAUDE_PID=$(pgrep -P "$PANE_PID" -x claude | head -1)
if [ -n "$CLAUDE_PID" ]; then
  echo "$(date): [$TARGET] 送 TERM 給 claude PID $CLAUDE_PID (pane_pid=$PANE_PID)" >> "$LOG"
  kill -TERM "$CLAUDE_PID"
  # 等 10 秒優雅退出
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if ! kill -0 "$CLAUDE_PID" 2>/dev/null; then
      echo "$(date): [$TARGET] claude PID $CLAUDE_PID 已退出" >> "$LOG"
      break
    fi
    sleep 1
  done
  # 10 秒後仍在 → fallback KILL（避免 supervisor 誤判為 fast-fail 而被自殺）
  if kill -0 "$CLAUDE_PID" 2>/dev/null; then
    echo "$(date): [$TARGET] claude PID $CLAUDE_PID 10 秒後仍在，送 KILL" >> "$LOG"
    kill -KILL "$CLAUDE_PID"
  fi
else
  echo "$(date): [$TARGET] pane $PANE_PID 下找不到 claude child，supervisor loop 會自行重啟" >> "$LOG"
fi
