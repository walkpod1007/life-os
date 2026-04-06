#!/bin/bash
# session-to-md.sh — 把 JSONL session transcripts 轉成 .md 存到 sessions/ 目錄
# 用途：讓 qmd 向量索引能搜尋完整對話
# 排程：由 realtime-summary.sh 尾端呼叫，或手動跑
#
# 只轉還沒轉過的檔案（用 .converted marker 追蹤）

set -euo pipefail

PROJ_DIR="$HOME/.claude/projects/-Users-Modema11434-Documents-Life-OS"
OUT_DIR="$HOME/Documents/Life-OS/sessions"
MARKER_DIR="$HOME/.claude/session-converted"
LOG="$HOME/.claude/logs/session-to-md.log"

mkdir -p "$OUT_DIR" "$MARKER_DIR"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [session-to-md] $*" >> "$LOG"; }

COUNT=0

for jsonl in "$PROJ_DIR"/*.jsonl; do
  [ -f "$jsonl" ] || continue

  UUID=$(basename "$jsonl" .jsonl)
  MARKER="$MARKER_DIR/$UUID"
  OUT_FILE="$OUT_DIR/$UUID.md"

  # 已轉過且 JSONL 沒有更新 → 跳過
  if [ -f "$MARKER" ] && [ "$jsonl" -ot "$MARKER" ]; then
    continue
  fi

  # 提取 [U]/[A] 純文字 + 時間戳
  python3 - "$jsonl" "$OUT_FILE" <<'PYEOF'
import sys, json, re
from datetime import datetime

jsonl_path = sys.argv[1]
out_path = sys.argv[2]

lines = []
session_start = None
session_end = None

with open(jsonl_path, 'r', encoding='utf-8', errors='replace') as f:
    for raw in f:
        raw = raw.strip()
        if not raw:
            continue
        try:
            obj = json.loads(raw)
        except:
            continue

        t = obj.get('type', '')
        msg = obj.get('message', {})
        content = msg.get('content', '')
        ts = obj.get('timestamp') or msg.get('timestamp')

        # Track session time range
        if ts:
            try:
                if isinstance(ts, (int, float)):
                    dt = datetime.fromtimestamp(ts / 1000 if ts > 1e12 else ts)
                else:
                    dt = datetime.fromisoformat(str(ts).replace('Z', '+00:00'))
                if session_start is None or dt < session_start:
                    session_start = dt
                if session_end is None or dt > session_end:
                    session_end = dt
            except:
                pass

        if t == 'user':
            text = ''
            if isinstance(content, list):
                for c in content:
                    if isinstance(c, dict) and c.get('type') == 'text':
                        text = c.get('text', '')
                        break
            elif isinstance(content, str):
                text = content
            # Strip XML tags (channel wrappers, system reminders, etc)
            text = re.sub(r'<system-reminder>.*?</system-reminder>', '', text, flags=re.DOTALL)
            text = re.sub(r'<channel[^>]*>.*?</channel>', '', text, flags=re.DOTALL)
            text = re.sub(r'<state>.*?</state>', '', text, flags=re.DOTALL)
            text = re.sub(r'<flag>.*?</flag>', '', text, flags=re.DOTALL)
            text = re.sub(r'<turn_protocol>.*?</turn_protocol>', '', text, flags=re.DOTALL)
            text = re.sub(r'<nav>.*?</nav>', '', text, flags=re.DOTALL)
            text = re.sub(r'<mode_protocol>.*?</mode_protocol>', '', text, flags=re.DOTALL)
            text = re.sub(r'<[^>]+>', '', text)
            text = text.strip()
            if text:
                lines.append(f'**U:** {text}')
                lines.append('')

        elif t == 'assistant':
            text = ''
            if isinstance(content, list):
                for c in content:
                    if isinstance(c, dict) and c.get('type') == 'text':
                        text += c.get('text', '') + '\n'
            elif isinstance(content, str):
                text = content
            text = text.strip()
            if text:
                lines.append(f'**A:** {text}')
                lines.append('')

# Write frontmatter + content
start_str = session_start.strftime('%Y-%m-%d %H:%M') if session_start else 'unknown'
end_str = session_end.strftime('%H:%M') if session_end else 'unknown'
date_str = session_start.strftime('%Y-%m-%d') if session_start else 'unknown'

with open(out_path, 'w', encoding='utf-8') as f:
    f.write(f'---\n')
    f.write(f'type: session-transcript\n')
    f.write(f'date: {date_str}\n')
    f.write(f'time: {start_str} — {end_str}\n')
    f.write(f'source: claude-code\n')
    f.write(f'---\n\n')
    f.write('\n'.join(lines))

print(f'OK {len(lines)} lines')
PYEOF

  touch "$MARKER"
  COUNT=$((COUNT + 1))
  log "converted: $UUID → $OUT_FILE"
done

if [ "$COUNT" -gt 0 ]; then
  log "done: $COUNT sessions converted"
  # Update qmd index
  qmd update -c lifeos >> "$LOG" 2>&1 || true
else
  log "no new sessions to convert"
fi
