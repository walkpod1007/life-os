#!/usr/bin/env bash
# Version: 1.0
# Last modified: 2026-03-03
# Status: active
# Level: B
# file-extract.sh — 提取文件內文
# 用法: ./file-extract.sh /tmp/somefile.pdf
# 輸出: 純文字到 stdout；同時將結構化資訊寫入 /tmp/line-last-file.json
# 依賴: pdftotext, docx2txt, python3(openpyxl), file

set -euo pipefail

FILE_PATH="${1:?需要傳入檔案路徑}"
FILENAME="$(basename "$FILE_PATH")"
EXT="${FILENAME##*.}"
EXT_LOWER="$(echo "$EXT" | tr '[:upper:]' '[:lower:]')"
MSG_ID="${2:-unknown}"

# 判斷檔案類型圖示
case "$EXT_LOWER" in
  pdf)  FILE_ICON="📄" ;;
  xlsx|xls) FILE_ICON="📊" ;;
  docx|doc) FILE_ICON="📝" ;;
  *) FILE_ICON="📃" ;;
esac

# 提取文字
EXTRACTED=""
META=""

case "$EXT_LOWER" in
  pdf)
    if command -v pdftotext &>/dev/null; then
      EXTRACTED="$(pdftotext "$FILE_PATH" - 2>/dev/null || true)"
      PAGE_COUNT="$(pdfinfo "$FILE_PATH" 2>/dev/null | awk '/^Pages:/{print $2}' || true)"
      [ -n "$PAGE_COUNT" ] && META="共 ${PAGE_COUNT} 頁"
    fi
    # 若提取結果為空 → 掃描版 PDF，fallback 到 vision（由上層處理）
    if [ -z "$(echo "$EXTRACTED" | tr -d '[:space:]')" ]; then
      echo "[SCAN_PDF]" >&2
      EXTRACTED="[SCAN_PDF]"
    fi
    ;;

  docx)
    if command -v docx2txt &>/dev/null; then
      EXTRACTED="$(docx2txt "$FILE_PATH" - 2>/dev/null || true)"
    elif command -v python3 &>/dev/null; then
      EXTRACTED="$(python3 - "$FILE_PATH" <<'PYEOF'
import sys, zipfile, re
try:
    with zipfile.ZipFile(sys.argv[1]) as z:
        xml = z.read('word/document.xml').decode('utf-8', errors='replace')
    text = re.sub(r'<[^>]+>', ' ', xml)
    print(' '.join(text.split()))
except Exception as e:
    print(f'[ERROR] {e}', file=sys.stderr)
PYEOF
)"
    fi
    WORD_COUNT="$(echo "$EXTRACTED" | wc -w | tr -d ' ')"
    META="約 ${WORD_COUNT} 字"
    ;;

  xlsx|xls)
    if command -v python3 &>/dev/null; then
      EXTRACTED="$(python3 - "$FILE_PATH" <<'PYEOF'
import sys
try:
    import openpyxl
    wb = openpyxl.load_workbook(sys.argv[1], read_only=True, data_only=True)
    rows = []
    for sh in wb.sheetnames:
        ws = wb[sh]
        rows.append(f"[Sheet: {sh}]")
        for row in ws.iter_rows(values_only=True):
            vals = [str(c) if c is not None else '' for c in row]
            if any(v.strip() for v in vals):
                rows.append('\t'.join(vals))
    print('\n'.join(rows[:200]))  # 最多 200 行
except Exception as e:
    print(f'[ERROR] {e}', file=sys.stderr)
PYEOF
)"
    fi
    SHEET_COUNT="$(python3 - "$FILE_PATH" <<'PYEOF' 2>/dev/null || echo "?"
import sys
try:
    import openpyxl
    wb = openpyxl.load_workbook(sys.argv[1], read_only=True)
    print(len(wb.sheetnames))
except:
    print('?')
PYEOF
)"
    META="${SHEET_COUNT} 個 Sheet"
    ;;

  txt|md|csv|tsv|log|json)
    EXTRACTED="$(cat "$FILE_PATH" 2>/dev/null || true)"
    LINE_COUNT="$(wc -l < "$FILE_PATH" | tr -d ' ')"
    META="共 ${LINE_COUNT} 行"
    ;;

  *)
    echo "[UNSUPPORTED_FORMAT] .${EXT_LOWER}" >&2
    EXTRACTED="[UNSUPPORTED_FORMAT]"
    ;;
esac

# 輸出提取文字到 stdout
echo "$EXTRACTED"

# 寫入 /tmp/line-last-file.json（供 postback 引用）
# summary 欄位由呼叫方（LLM/上層腳本）填入，這裡預先填空
SUMMARY_PLACEHOLDER=""

python3 - <<PYEOF
import json, sys, os

data = {
    "msg_id": "${MSG_ID}",
    "file_path": "${FILE_PATH}",
    "filename": "${FILENAME}",
    "filetype": "${EXT_LOWER}",
    "file_icon": "${FILE_ICON}",
    "meta": "${META}",
    "summary": ""
}
with open('/tmp/line-last-file.json', 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
PYEOF
