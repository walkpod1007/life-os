#!/bin/bash
# token-watchdog.sh — 監控 Claude Code token 用量，達 150k 自動重啟
# 流程：session-end hook（寫 handoff）→ realtime-summary（更新 STATE）→ 殺 claude → supervisor 重啟

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/hooks"

TMUX_TARGET="${1:?ERROR: token-watchdog requires a session name argument}"
THRESHOLD=150000
CHECK_INTERVAL=60
# log 跟對應 supervisor 寫同一個檔案，方便 debug 時看完整流程
case "$TMUX_TARGET" in
  claude-telegram) LOG="$HOME/.claude/claude-telegram.log" ;;
  claude-line)     LOG="$HOME/.claude/claude-line.log" ;;
  claude-line-note) LOG="$HOME/.claude/claude-line-note.log" ;;
  claude-remote)   LOG="$HOME/.claude/claude-remote.log" ;;
  claude-terminal) LOG="$HOME/.claude/claude-terminal.log" ;;
  *)               LOG="$HOME/.claude/supervisor.log" ;;
esac
SELF_RESTART="$SCRIPT_DIR/self-restart.sh"
REALTIME_SUMMARY="$SCRIPT_DIR/realtime-summary.sh"
TRIGGERED_FLAG="$HOME/.claude/watchdog-token-triggered-${TMUX_TARGET}"
# 同時守 Life-OS 專案目錄與使用者家目錄（裸啟動的 session 會寫進後者）
# 注意：project dir 名稱大小寫要與 claude code 實際路徑一致（Life-OS 大寫）
PROJ_DIRS=(
    "$HOME/.claude/projects/-Users-applyao-Documents-Life-OS"
    "$HOME/.claude/projects/-Users-applyao"
)
# 只看 mtime 在此秒數內有更新的 jsonl，避免舊 session 殘留 token 值誤觸發
ACTIVE_WINDOW_SECS=600

echo "$(date): token-watchdog[$TMUX_TARGET] 啟動 (threshold: ${THRESHOLD})" >> "$LOG"
# 新 watchdog 代表新 session，清掉上一輪殘留的 triggered flag
if [ -f "$TRIGGERED_FLAG" ]; then
    rm -f "$TRIGGERED_FLAG"
    echo "$(date): token-watchdog[$TMUX_TARGET] 啟動時清除殘留 flag（新 session 乾淨開始）" >> "$LOG"
fi

# ── Health check 設定 ──────────────────────────────────────────────────────────
HEALTH_CHECK_INTERVAL=60    # 每 1 分鐘做一次（MCP 死亡最慢 120 秒偵測到）
QUEUE_STALE_SECS=300        # queue 有內容且超過 5 分鐘未清 → 補觸發
LAST_HEALTH_CHECK=0

# 各 session 對應的 queue 檔路徑（沒有 queue 的 session 留空）
case "$TMUX_TARGET" in
  claude-line)      HEALTH_QUEUE="$HOME/.claude/channels/line/runtime/line-lobster-queue.jsonl" ;;
  claude-line-note) HEALTH_QUEUE="$HOME/.claude/channels/line/runtime/line-lobster-queue-line-note.jsonl" ;;
  claude-telegram)  HEALTH_QUEUE="$HOME/.claude/channels/telegram/runtime/tg-queue.jsonl" ;;
  *)                HEALTH_QUEUE="" ;;
esac

# health check 補觸發用語
case "$TMUX_TARGET" in
  claude-line|claude-line-note) HEALTH_TRIGGER="請呼叫 get_pending 讀取待處理的 LINE 訊息並回覆。" ;;
  claude-telegram)              HEALTH_TRIGGER="請呼叫 get_pending 讀取待處理的 Telegram 訊息並回覆。" ;;
  *)                            HEALTH_TRIGGER="" ;;
esac

# MCP server 存活確認設定
case "$TMUX_TARGET" in
  claude-line|claude-line-note) MCP_BINARY="line-lobster/server.ts" ;;
  claude-telegram)              MCP_BINARY="telegram-lobster/server.ts" ;;
  *)                            MCP_BINARY="" ;;
esac
MCP_KILL_COUNT=0
MCP_KILL_LIMIT=3  # 最多觸發 3 次 kill，防止 MCP 持續失敗造成 kill loop
MCP_GRACE_SECS=120  # watchdog 啟動後前 120 秒不做 MCP check（等 claude + MCP 完全就緒）
WATCHDOG_START_TS=$(date +%s)

# ── Session pinning：用 lsof 鎖定本 session claude 正在寫的 JSONL ──
# watchdog 是 supervisor 的 background child，supervisor 也是 claude 的 parent。
# 透過 PPID 找到同一個 supervisor 下的 claude，再用 lsof 找它開著的 .jsonl。
PINNED_JSONL=""
SUPERVISOR_PID="$PPID"  # watchdog 的 parent 就是 supervisor

while true; do
    sleep "$CHECK_INTERVAL"

    # ── Health check（每 2 分鐘）────────────────────────────────────────────
    NOW_HC=$(date +%s)
    if [ $((NOW_HC - LAST_HEALTH_CHECK)) -ge "$HEALTH_CHECK_INTERVAL" ]; then
        LAST_HEALTH_CHECK=$NOW_HC

        # 1. Permission dialog 偵測 → 自動 Escape 解鎖
        PANE=$(tmux capture-pane -t "$TMUX_TARGET" -p 2>/dev/null)
        if echo "$PANE" | grep -qE "Do you want to make this edit|Do you want to run this command|allow Claude to edit|1\. Yes|2\. Yes, and allow"; then
            echo "$(date): health-check[$TMUX_TARGET] ⚠️ permission dialog 偵測，送 Escape 解鎖" >> "$LOG"
            tmux send-keys -t "$TMUX_TARGET" Escape 2>/dev/null
        fi

        # 2. Queue 積壓偵測 → 補觸發 get_pending
        if [ -n "$HEALTH_QUEUE" ] && [ -f "$HEALTH_QUEUE" ]; then
            QUEUE_SIZE=$(wc -l < "$HEALTH_QUEUE" 2>/dev/null || echo 0)
            QUEUE_MTIME=$(stat -f %m "$HEALTH_QUEUE" 2>/dev/null || echo 0)
            if [ "$QUEUE_SIZE" -gt 0 ] && [ $((NOW_HC - QUEUE_MTIME)) -gt "$QUEUE_STALE_SECS" ]; then
                echo "$(date): health-check[$TMUX_TARGET] ⚠️ queue 積壓 ${QUEUE_SIZE}B / $((NOW_HC - QUEUE_MTIME))s，補觸發" >> "$LOG"
                # 共用 cooldown，與 webhook 同步
                TRIGGER_COOLDOWN_FILE=""
                case "$HEALTH_QUEUE" in
                  *tg-queue.jsonl) TRIGGER_COOLDOWN_FILE="$HOME/.claude/channels/telegram/runtime/tg-trigger-cooldown" ;;
                  *line-lobster-queue.jsonl) TRIGGER_COOLDOWN_FILE="$HOME/.claude/channels/line/runtime/line-trigger-cooldown-claude-line" ;;
                  *line-lobster-queue-line-note.jsonl) TRIGGER_COOLDOWN_FILE="$HOME/.claude/channels/line/runtime/line-trigger-cooldown-claude-line-note" ;;
                esac
                SHOULD_TRIGGER=1
                if [ -n "$TRIGGER_COOLDOWN_FILE" ]; then
                  NOW_MS=$(date +%s%3N)
                  LAST_MS=0
                  [ -f "$TRIGGER_COOLDOWN_FILE" ] && LAST_MS=$(cat "$TRIGGER_COOLDOWN_FILE" 2>/dev/null || echo 0)
                  if [ $((NOW_MS - LAST_MS)) -lt 30000 ]; then
                    echo "$(date): health-check[$TMUX_TARGET] trigger skipped (cooldown active)" >> "$LOG"
                    SHOULD_TRIGGER=0
                  else
                    echo "$NOW_MS" > "$TRIGGER_COOLDOWN_FILE"
                  fi
                fi
                if [ "$SHOULD_TRIGGER" = "1" ] && [ -n "$HEALTH_TRIGGER" ]; then
                  tmux send-keys -t "$TMUX_TARGET" "$HEALTH_TRIGGER" Enter 2>/dev/null
                fi
            fi
        fi

        # 4. MCP server 存活確認（啟動 120 秒寬限期後才開始檢查）
        if [ -n "$MCP_BINARY" ] && [ "$MCP_KILL_COUNT" -lt "$MCP_KILL_LIMIT" ] && [ $((NOW_HC - WATCHDOG_START_TS)) -gt "$MCP_GRACE_SECS" ]; then
          CLAUDE_PID=$(pgrep -P "$SUPERVISOR_PID" -x claude 2>/dev/null | head -1)
          if [ -n "$CLAUDE_PID" ]; then
            MCP_PID=$(pgrep -P "$CLAUDE_PID" -f "$MCP_BINARY" 2>/dev/null | head -1)
            if [ -z "$MCP_PID" ]; then
              MCP_KILL_COUNT=$((MCP_KILL_COUNT + 1))
              echo "$(date): health-check[$TMUX_TARGET] ⚠️ MCP $MCP_BINARY 不存在，kill claude 重啟整條 (kill #$MCP_KILL_COUNT/$MCP_KILL_LIMIT)" >> "$LOG"
              kill "$CLAUDE_PID" 2>/dev/null
            else
              # MCP 健康，重置計數器
              MCP_KILL_COUNT=0
            fi
          fi
        elif [ "$MCP_KILL_COUNT" -ge "$MCP_KILL_LIMIT" ]; then
          echo "$(date): health-check[$TMUX_TARGET] ⛔ MCP kill 次數達上限 $MCP_KILL_LIMIT，停止自動 kill，請人工介入" >> "$LOG"
        fi
    fi

    # ── 如果尚未 pin，透過 lsof 找 claude 正在寫的 JSONL ──
    if [ -z "$PINNED_JSONL" ]; then
        CLAUDE_PID=$(pgrep -P "$SUPERVISOR_PID" -x claude 2>/dev/null | head -1)
        if [ -n "$CLAUDE_PID" ]; then
            # lsof 找 claude 開著的 .jsonl 檔案
            CANDIDATE=$(lsof -p "$CLAUDE_PID" 2>/dev/null | grep '\.jsonl' | awk '{print $NF}' | head -1)
            if [ -n "$CANDIDATE" ] && [ -f "$CANDIDATE" ]; then
                PINNED_JSONL="$CANDIDATE"
                echo "$(date): token-watchdog[$TMUX_TARGET] pinned JSONL (via lsof claude PID $CLAUDE_PID): $(basename "$PINNED_JSONL")" >> "$LOG"
            fi
        fi
        [ -z "$PINNED_JSONL" ] && continue
    fi

    # ── 只監控 pinned JSONL ──
    if [ ! -f "$PINNED_JSONL" ]; then
        echo "$(date): token-watchdog[$TMUX_TARGET] pinned JSONL 消失，重置 pin" >> "$LOG"
        PINNED_JSONL=""
        continue
    fi

    # 檢查 pinned file 是否還在活躍（mtime 在 ACTIVE_WINDOW 內）
    MTIME=$(stat -f %m "$PINNED_JSONL" 2>/dev/null || echo 0)
    NOW_TS=$(date +%s)
    if [ $((NOW_TS - MTIME)) -gt "$ACTIVE_WINDOW_SECS" ]; then
        continue  # session 靜默中，不需要檢查
    fi

    # 讀取 pinned JSONL 的 token 數
    read -r CURRENT_TOKENS TRANSCRIPT < <(python3 - "$PINNED_JSONL" << 'PYEOF'
import json, sys

best_total = 0
best_path = ""
for transcript in sys.argv[1:]:
    last_total = 0
    try:
        with open(transcript, encoding='utf-8', errors='replace') as f:
            for line in f:
                try:
                    d = json.loads(line)
                    u = (d.get('message') or {}).get('usage') or d.get('usage') or {}
                    total = (
                        u.get('input_tokens', 0) +
                        u.get('cache_read_input_tokens', 0) +
                        u.get('cache_creation_input_tokens', 0)
                    )
                    if total > 0:
                        last_total = total
                except:
                    continue
    except:
        pass
    if last_total > best_total:
        best_total = last_total
        best_path = transcript
print(f"{best_total} {best_path}")
PYEOF
    )

    CURRENT_TOKENS=${CURRENT_TOKENS:-0}
    TRANSCRIPT=${TRANSCRIPT:-}

    if [ "$CURRENT_TOKENS" -ge "$THRESHOLD" ] 2>/dev/null; then
        if [ ! -f "$TRIGGERED_FLAG" ]; then
            echo "$(date): ⚠️ token watchdog 觸發！${CURRENT_TOKENS} >= ${THRESHOLD}，開始重啟流程 ($TMUX_TARGET)" >> "$LOG"
            touch "$TRIGGERED_FLAG"
            TRANSCRIPT_PATH="$TRANSCRIPT"

            # Step 0: gen-handoff（用 Haiku 從 transcript 產 4 段 handoff.md）
            echo "$(date): token-watchdog → step0 gen-handoff" >> "$LOG"
            GEN_HANDOFF="$SCRIPT_DIR/gen-handoff.sh"
            if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$GEN_HANDOFF" ]; then
                bash "$GEN_HANDOFF" "$TRANSCRIPT_PATH" >> "$LOG" 2>&1 || \
                    echo "$(date): token-watchdog → gen-handoff 非零退出（保留原 handoff）" >> "$LOG"
            fi

            # Step 1: session-end hook（寫 daily log 冷儲存）
            echo "$(date): token-watchdog → step1 session-end hook" >> "$LOG"
            SESSION_END_HOOK="$HOOKS_DIR/claude-hook-session-end.sh"
            if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$SESSION_END_HOOK" ]; then
                echo "{\"transcript_path\": \"$TRANSCRIPT_PATH\"}" | bash "$SESSION_END_HOOK" >> "$LOG" 2>&1 || true
            elif [ -z "$TRANSCRIPT_PATH" ]; then
                echo "$(date): token-watchdog → 找不到 transcript，跳過 session-end hook" >> "$LOG"
            else
                echo "$(date): token-watchdog → 缺少 session-end hook：$SESSION_END_HOOK" >> "$LOG"
            fi

            # Step 2: realtime-summary（補足最後幾分鐘 + 更新 STATE.md）
            echo "$(date): token-watchdog → step2 realtime-summary" >> "$LOG"
            bash "$REALTIME_SUMMARY" >> "$LOG" 2>&1 || true

            # Step 3: 殺 claude（交由 supervisor while loop 重啟）
            echo "$(date): token-watchdog → step3 self-restart ($TMUX_TARGET)" >> "$LOG"
            bash "$SELF_RESTART" "$TMUX_TARGET" &
        fi
    else
        # 重啟完成後新 session 的 tokens 會回到低點，清掉 flag
        if [ -f "$TRIGGERED_FLAG" ] && [ "$CURRENT_TOKENS" -lt 5000 ] 2>/dev/null; then
            rm -f "$TRIGGERED_FLAG"
            echo "$(date): token-watchdog flag 清除（新 session 已啟動）" >> "$LOG"
        fi
    fi
done
