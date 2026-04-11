#!/bin/bash
# token-watchdog.sh — 監控 Claude Code token 用量，達 150k 自動重啟
# 流程：session-end hook（寫 handoff）→ realtime-summary（更新 STATE）→ 殺 claude → supervisor 重啟

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/hooks"

TMUX_TARGET="${1:-claude-telegram}"   # 接受參數，預設 claude-telegram
THRESHOLD=150000
CHECK_INTERVAL=60
LOG="$HOME/.claude/supervisor.log"
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

echo "$(date): token-watchdog 啟動 (threshold: ${THRESHOLD}k)" >> "$LOG"
# 新 watchdog 代表新 session，清掉上一輪殘留的 triggered flag
if [ -f "$TRIGGERED_FLAG" ]; then
    rm -f "$TRIGGERED_FLAG"
    echo "$(date): token-watchdog 啟動時清除殘留 flag（新 session 乾淨開始）" >> "$LOG"
fi

while true; do
    sleep "$CHECK_INTERVAL"

    # 蒐集所有活躍 jsonl（mtime 在 ACTIVE_WINDOW_SECS 秒內有動）
    ACTIVE_LIST=()
    for dir in "${PROJ_DIRS[@]}"; do
        [ -d "$dir" ] || continue
        while IFS= read -r f; do
            [ -n "$f" ] && ACTIVE_LIST+=("$f")
        done < <(find "$dir" -maxdepth 1 -name "*.jsonl" -type f -mmin "-$((ACTIVE_WINDOW_SECS / 60 + 1))" 2>/dev/null)
    done

    if [ "${#ACTIVE_LIST[@]}" -eq 0 ]; then
        continue
    fi

    # 掃所有活躍 jsonl，取最大的 context token 值跟對應檔案
    read -r CURRENT_TOKENS TRANSCRIPT < <(python3 - "${ACTIVE_LIST[@]}" << 'PYEOF'
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
