#!/bin/bash
TMUX_SESSION="claude-life"
STOP_FLAG="$HOME/.claude/supervisor-stop"
RESTART_FLAG="$HOME/.claude/supervisor-restart"
RESTART_CMD="cd $HOME/Documents/Life-OS && claude --model sonnet --channels plugin:telegram@claude-plugins-official"
LOG="$HOME/.claude/supervisor.log"

if [ -z "$TMUX" ]; then
  echo "$(date): 包進 tmux '$TMUX_SESSION'" >> "$LOG"
  tmux kill-session -t "$TMUX_SESSION" 2>/dev/null
  tmux new-session -d -s "$TMUX_SESSION" "bash $HOME/Documents/Life-OS/scripts/claude-supervisor.sh"
  echo "$(date): tmux session 已建立" >> "$LOG"
  exit 0
fi

echo "$(date): supervisor 在 tmux 內啟動" >> "$LOG"
rm -f "$STOP_FLAG"

while true; do
  eval "$RESTART_CMD"
  EXIT_CODE=$?
  echo "$(date): claude 結束 (exit $EXIT_CODE)" >> "$LOG"

  if [ -f "$STOP_FLAG" ]; then
    echo "$(date): stop flag，停止" >> "$LOG"
    rm -f "$STOP_FLAG"; exit 0
  fi

  if [ -f "$RESTART_FLAG" ]; then
    rm -f "$RESTART_FLAG"
    echo "$(date): restart flag，3 秒後重啟..." >> "$LOG"
    sleep 3
    # 重置終端狀態，避免前一個 Claude 被 SIGTERM 後 stdin 異常
    # 注意：不要用 reset，在 tmux 裡會破壞 stdin
    stty sane 2>/dev/null
    sleep 2
    echo "$(date): 重啟 claude..." >> "$LOG"
    continue
  fi

  echo "$(date): 無旗標，停止" >> "$LOG"
  exit 0
done
