#!/bin/bash
# security-gate-hook.sh — WO-035 H2
# 用法：security-gate-hook.sh <red|yellow|green> <操作描述>
# exit 0 = 綠線，可執行
# exit 1 = 非法參數
# exit 2 = 等待確認（red/yellow）

LEVEL="${1:-}"
OPERATION="${2:-未知操作}"
TIMESTAMP=$(date +%s)
TIMEOUT=60
PENDING_FILE="/tmp/security-gate-pending.json"

write_pending() {
  local level="$1"
  local op="$2"
  local tmp
  tmp=$(mktemp /tmp/security-gate-pending.XXXXXX.json)

  printf '{"level":"%s","operation":%s,"timestamp":%s,"timeout":%s}\n' \
    "$level" "$(printf '%s' "$op" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" "$TIMESTAMP" "$TIMEOUT" > "$tmp"

  if [ ! -s "$tmp" ]; then
    rm -f "$tmp"
    echo "❌ pending 旗標寫入失敗（empty）"
    exit 1
  fi

  mv -f "$tmp" "$PENDING_FILE"
  sync "$PENDING_FILE" 2>/dev/null || true

  if [ ! -s "$PENDING_FILE" ]; then
    echo "❌ pending 旗標寫入失敗（missing）"
    exit 1
  fi
}

case "$LEVEL" in
  red)
    echo "🔴 紅線操作攔截：$OPERATION"
    echo "此操作需要明確確認才能繼續。"
    echo "請在 LINE 回覆「做」或「執行」，$TIMEOUT 秒內無回應視為取消。"
    write_pending "red" "$OPERATION"
    exit 2
    ;;
  yellow)
    echo "🟡 黃線操作通知：$OPERATION"
    echo "即將執行，$TIMEOUT 秒內無回應視為取消。"
    write_pending "yellow" "$OPERATION"
    exit 2
    ;;
  green)
    exit 0
    ;;
  *)
    echo "❌ 非法參數：$LEVEL（應為 red / yellow / green）"
    exit 1
    ;;
esac
