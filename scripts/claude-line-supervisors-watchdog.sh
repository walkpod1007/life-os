#!/bin/bash
# DEPRECATED 2026-04-29: superseded by ~/bin/life-os-watchdog/watchdog.sh
# Reason: macOS Sequoia 重開機後 cron FDA stale，新 watchdog 放 ~/bin/ 確保 cron 失 FDA 也能 spawn 並告警
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
PROTECTED_DIR="$HOME/Documents/life-os"
SCRIPTS_DIR="$PROTECTED_DIR/scripts"
LOG=/tmp/claude-line-watchdog.log

CHANNELS=(claude-line claude-line-note claude-line-talk claude-line-ita claude-line-recipe claude-line-ptcg claude-remote)

echo "$(date +%Y-%m-%d_%H:%M:%S) watchdog tick" >> $LOG

for s in "${CHANNELS[@]}"; do
    if [ -x "$SCRIPTS_DIR/$s.sh" ]; then
        bash "$SCRIPTS_DIR/$s.sh" >> $LOG 2>&1 &
    else
        echo "$s: missing" >> $LOG
    fi
done

wait
echo "$(date +%Y-%m-%d_%H:%M:%S) watchdog done" >> $LOG