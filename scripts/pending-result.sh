#!/usr/bin/env bash
# Version: 1.0
# Last modified: 2026-03-17
# Status: active
# Level: B
# pending-result.sh — LINE Reply API 搭便車暫存
# 用法：
#   pending-result.sh write '<JSON>'  # 寫入 pending
#   pending-result.sh read            # 讀取（超過 30 分鐘自動清空）
#   pending-result.sh clear           # 清空

PENDING_FILE="/tmp/line-pending-result.json"
EXPIRE_SECONDS=1800  # 30 分鐘

cmd="${1}"

case "$cmd" in
  write)
    payload="${2}"
    if [[ -z "$payload" ]]; then
      echo "ERROR: write requires a JSON payload" >&2
      exit 1
    fi
    # 加上 written_at timestamp
    ts=$(date +%s)
    # 用 python3 合併 timestamp（避免 jq 不一定存在）
    merged=$(python3 -c "
import sys, json
data = json.loads(sys.argv[1])
data['written_at'] = int(sys.argv[2])
print(json.dumps(data))
" "$payload" "$ts" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
      # fallback：直接存原始 payload + written_at 欄位
      echo "{\"written_at\":${ts},\"raw\":$(echo "$payload" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read().strip()))')}" > "$PENDING_FILE"
    else
      echo "$merged" > "$PENDING_FILE"
    fi
    echo "OK: pending written to $PENDING_FILE"
    ;;

  read)
    if [[ ! -f "$PENDING_FILE" ]]; then
      echo ""
      exit 0
    fi
    # 檢查是否過期
    written_at=$(python3 -c "
import json, sys
try:
    data = json.load(open(sys.argv[1]))
    print(data.get('written_at', 0))
except:
    print(0)
" "$PENDING_FILE" 2>/dev/null)
    now=$(date +%s)
    age=$(( now - written_at ))
    if [[ $age -gt $EXPIRE_SECONDS ]]; then
      rm -f "$PENDING_FILE"
      echo ""
      exit 0
    fi
    cat "$PENDING_FILE"
    ;;

  clear)
    rm -f "$PENDING_FILE"
    echo "OK: cleared"
    ;;

  *)
    echo "Usage: $0 {write '<JSON>'|read|clear}" >&2
    exit 1
    ;;
esac
