#!/bin/bash
# gen-handoff.sh — 從 session transcript 自動產生 4 段 handoff.md
#
# 使用：
#   bash gen-handoff.sh [transcript_path]
#   不傳參數時，自動抓 ~/.claude/projects/-Users-applyao-Documents-Life-OS/ 下最新的 jsonl
#
# 流程：
#   1. 解析 transcript，抽出 user + assistant 文字對話
#   2. 取最後 ~15000 字（控制 Haiku context 成本）
#   3. 用 claude -p --model haiku 產生 4 段 handoff
#   4. 驗證輸出包含 SUMMARY/CURRENT/NEXT/LESSON 四個 section
#   5. 通過驗證才覆寫 handoff.md（否則保留原檔不動）

set -u

PROJ_DIR="$HOME/.claude/projects/-Users-applyao-Documents-Life-OS"
HANDOFF="$HOME/Documents/Life-OS/handoff.md"
LOG="$HOME/.claude/supervisor.log"
MODEL="claude-haiku-4-5-20251001"
MAX_CHARS=15000   # 約 4k tokens 輸入，Haiku context 富餘

TRANSCRIPT="${1:-}"
if [ -z "$TRANSCRIPT" ]; then
  TRANSCRIPT=$(ls -t "$PROJ_DIR"/*.jsonl 2>/dev/null | head -1)
fi

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  echo "$(date): gen-handoff 找不到 transcript，跳過" >> "$LOG"
  exit 1
fi

echo "$(date): gen-handoff 開始解析 $TRANSCRIPT" >> "$LOG"

# 1. 抽對話內容（純 python，沿用 session-end hook 的清洗邏輯）
DIALOGUE=$(python3 - "$TRANSCRIPT" "$MAX_CHARS" << 'PYEOF'
import json, sys, re

transcript = sys.argv[1]
max_chars = int(sys.argv[2])

def extract_text(raw):
    raw = raw.strip()
    m = re.search(r'<channel[^>]*>\s*(.*?)\s*</channel>', raw, re.DOTALL)
    if m:
        text = m.group(1).strip()
    else:
        text = raw
    text = re.sub(r'<state>.*?</state>', '', text, flags=re.DOTALL)
    text = re.sub(r'<flag>.*?</flag>', '', text, flags=re.DOTALL)
    text = re.sub(r'<turn_protocol>.*?</turn_protocol>', '', text, flags=re.DOTALL)
    text = re.sub(r'<nav>.*?</nav>', '', text, flags=re.DOTALL)
    text = re.sub(r'<mode_protocol>.*?</mode_protocol>', '', text, flags=re.DOTALL)
    text = re.sub(r'<system-reminder>.*?</system-reminder>', '', text, flags=re.DOTALL)
    text = re.sub(r'<[^>]+>', '', text).strip()
    return text if len(text) >= 5 else None

msgs = []
try:
    with open(transcript, encoding='utf-8', errors='replace') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
                role = d.get('type')
                if role == 'user':
                    prefix = 'U'
                    content = d.get('message', {}).get('content', '')
                elif role == 'assistant':
                    prefix = 'A'
                    content = d.get('message', {}).get('content', '')
                else:
                    continue
                if isinstance(content, str):
                    text = extract_text(content)
                    if text:
                        msgs.append(f"[{prefix}] {text}")
                elif isinstance(content, list):
                    for block in content:
                        if isinstance(block, dict) and block.get('type') == 'text':
                            text = extract_text(block.get('text', ''))
                            if text:
                                msgs.append(f"[{prefix}] {text}")
            except Exception:
                continue
except Exception:
    pass

# 取最後 N 字（從尾端往前累積）
joined = "\n".join(msgs)
if len(joined) > max_chars:
    joined = joined[-max_chars:]
    # 對齊到下一個 [U] 或 [A] 標記，避免從半句開始
    idx = joined.find("\n[")
    if idx > 0:
        joined = joined[idx+1:]
print(joined)
PYEOF
)

if [ -z "$DIALOGUE" ]; then
  echo "$(date): gen-handoff 對話內容為空，跳過" >> "$LOG"
  exit 1
fi

# 2. 用 claude -p 產生 handoff
PROMPT="你是一個 session handoff 撰寫助手。請讀下方 transcript，產出一份 4 段 handoff，格式嚴格如下：

## SUMMARY（這串做了什麼）

## CURRENT（現在是什麼狀態）

## NEXT（下一步）

## LESSON（踩坑與學到的）

規則：
- 每段 3-5 句話，寫結論不寫過程
- 讀完 30 秒內要知道現況
- LESSON 段記錄今天新學到或踩過的坑，沒有就寫「無」
- 只輸出 4 個 section，不要加前言、結尾、或其他裝飾

---TRANSCRIPT BEGINS---
${DIALOGUE}
---TRANSCRIPT ENDS---"

echo "$(date): gen-handoff 呼叫 claude -p (model: $MODEL, prompt: $(echo -n "$PROMPT" | wc -c) chars)" >> "$LOG"

TIMEOUT_SECS=120  # 2 分鐘上限，防止 API 卡住阻塞重啟流程
OUTPUT=$(timeout "$TIMEOUT_SECS" bash -c 'printf "%s\n" "$1" | claude -p --model "$2" 2>>"$3"' _ "$PROMPT" "$MODEL" "$LOG")
RC=$?

if [ $RC -eq 124 ]; then
  echo "$(date): gen-handoff 超時（${TIMEOUT_SECS}s），��留原 handoff" >> "$LOG"
  exit 2
fi

if [ $RC -ne 0 ] || [ -z "$OUTPUT" ]; then
  echo "$(date): gen-handoff claude -p 失敗 (rc=$RC, output=$(echo -n "$OUTPUT" | wc -c) chars)，保留原 handoff" >> "$LOG"
  exit 2
fi

# 3. 驗證輸出含 4 個 section header
if ! echo "$OUTPUT" | grep -q "## SUMMARY"; then VALIDATE_FAIL="SUMMARY"; fi
if ! echo "$OUTPUT" | grep -q "## CURRENT"; then VALIDATE_FAIL="${VALIDATE_FAIL:-}CURRENT "; fi
if ! echo "$OUTPUT" | grep -q "## NEXT"; then VALIDATE_FAIL="${VALIDATE_FAIL:-}NEXT "; fi
if ! echo "$OUTPUT" | grep -q "## LESSON"; then VALIDATE_FAIL="${VALIDATE_FAIL:-}LESSON "; fi

if [ -n "${VALIDATE_FAIL:-}" ]; then
  echo "$(date): gen-handoff 驗證失敗（缺: $VALIDATE_FAIL），保留原 handoff" >> "$LOG"
  echo "$OUTPUT" > "/tmp/gen-handoff-rejected-$(date +%Y%m%d-%H%M%S).md"
  exit 3
fi

# 4. 備份原 handoff + 覆寫
if [ -f "$HANDOFF" ]; then
  cp "$HANDOFF" "/tmp/handoff-before-gen-$(date +%Y%m%d-%H%M%S).md"
fi
echo "$OUTPUT" > "$HANDOFF"
echo "$(date): gen-handoff 成功覆寫 $HANDOFF ($(echo -n "$OUTPUT" | wc -c) chars)" >> "$LOG"
exit 0
