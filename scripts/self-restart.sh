#!/bin/bash
# self-restart.sh — 讓 Claude 自行重啟（含日檔寫入）
# 呼叫前 Claude 應先把本次重點寫入 MEMORY.md
#
# 流程：
#   1. 手動觸發 SessionEnd hook → 寫日檔
#   2. 等 60 秒讓 hook 跑完
#   3. 若 supervisor 未在跑 → 啟動
#   4. 殺掉當前 claude 進程

RESTART_FLAG="$HOME/.claude/supervisor-restart"
STOP_FLAG="$HOME/.claude/supervisor-stop"
SUPERVISOR="$HOME/Documents/Life-OS/scripts/claude-supervisor.sh"
SESSION_END_HOOK="/Users/Modema11434/.openclaw/workspace/scripts/claude-hook-session-end.sh"
LOG="$HOME/.claude/supervisor.log"

echo "$(date): self-restart 觸發" >> "$LOG"

# 1. 手動觸發 SessionEnd hook
# 找 transcript 路徑（從最新的 projects transcript）
TRANSCRIPT=$(find "$HOME/.claude/projects" -name "*.jsonl" -newer "$HOME/.claude/supervisor.log" 2>/dev/null | sort -t/ -k1 | tail -1)
if [ -z "$TRANSCRIPT" ]; then
  TRANSCRIPT=$(ls -t "$HOME/.claude/projects/-Users-Modema11434-Documents-Life-OS"/*.jsonl 2>/dev/null | head -1)
fi

if [ -n "$TRANSCRIPT" ] && [ -f "$SESSION_END_HOOK" ]; then
  echo "$(date): 手動觸發 SessionEnd hook → $TRANSCRIPT" >> "$LOG"
  echo "{\"transcript_path\": \"$TRANSCRIPT\"}" | bash "$SESSION_END_HOOK" >> "$LOG" 2>&1
fi

# 2. 等 30 秒讓 hook 跑完
echo "$(date): 等待 30 秒..." >> "$LOG"
sleep 30

# 3. 建立重啟旗標
touch "$RESTART_FLAG"
rm -f "$STOP_FLAG"

# 4. 確認 supervisor tmux session 存在
if ! tmux has-session -t "claude-life" 2>/dev/null; then
  echo "$(date): ⚠️ supervisor tmux 不存在，啟動新 supervisor" >> "$LOG"
  rm -f "$RESTART_FLAG"  # supervisor 啟動時不需要 flag
  bash "$SUPERVISOR" &
  sleep 3
  echo "$(date): 新 supervisor 已啟動，不需殺 claude（它會自行結束）" >> "$LOG"
  exit 0
fi

# 5. 殺掉當前 claude session — 讓已在跑的 supervisor while loop 處理重啟
CLAUDE_PID=$(pgrep -f "claude.*--channels" | head -1)
if [ -z "$CLAUDE_PID" ]; then
  CLAUDE_PID=$(pgrep -f "^claude " | head -1)
fi
if [ -n "$CLAUDE_PID" ]; then
  echo "$(date): 殺掉 claude PID $CLAUDE_PID（交由 supervisor while loop 重啟）" >> "$LOG"
  kill -TERM "$CLAUDE_PID"
else
  echo "$(date): 找不到 claude PID，supervisor loop 會自行重啟" >> "$LOG"
fi
