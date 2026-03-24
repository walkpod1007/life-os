#!/usr/bin/env bash
# vault-waste-detect.sh
# 偵測 30_Resources 廢檔，Gemini 批次判斷，輸出報告

VAULT="/Users/Modema11434/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault"
TARGET="$VAULT/30_Resources"
REPORT="/Users/Modema11434/Documents/Life-OS/scripts/waste-report.md"

echo "# Vault 廢檔偵測報告" > "$REPORT"
echo "生成時間：$(date '+%Y-%m-%d %H:%M')" >> "$REPORT"
echo "" >> "$REPORT"

WASTE_COUNT=0
STUB_COUNT=0
KEEP_COUNT=0

echo "## ❌ 明確廢檔（自動判定）" >> "$REPORT"
echo "" >> "$REPORT"

# 第一輪：自動判定廢檔
find "$TARGET" -name "*.md" | while read -r f; do
  name=$(basename "$f")
  lines=$(wc -l < "$f" 2>/dev/null || echo 0)
  content=$(cat "$f" 2>/dev/null)

  # 判斷條件
  is_empty_index=false
  is_empty_stub=false

  # INDEX.md 且 table 無資料行
  if [[ "$name" == "INDEX.md" ]]; then
    data_rows=$(echo "$content" | grep -v "^|---" | grep -c "^|" || echo 0)
    if [[ "$data_rows" -le 2 ]]; then
      is_empty_index=true
    fi
  fi

  # 行數 < 8 且只有標題
  if [[ "$lines" -le 8 && "$name" != "INDEX.md" ]]; then
    real_content=$(echo "$content" | grep -v "^---" | grep -v "^#" | grep -v "^>" | grep -v "^$" | wc -l)
    if [[ "$real_content" -le 2 ]]; then
      is_empty_stub=true
    fi
  fi

  if $is_empty_index || $is_empty_stub; then
    echo "- \`$f\`" >> "$REPORT"
    echo "WASTE|$f"
  fi
done

echo "" >> "$REPORT"
echo "## ⚠️ Gemini 判斷（疑似廢檔）" >> "$REPORT"
echo "" >> "$REPORT"

# 第二輪：把 10-30 行的疑似檔案送 Gemini 判斷
find "$TARGET" -name "*.md" | while read -r f; do
  name=$(basename "$f")
  lines=$(wc -l < "$f" 2>/dev/null || echo 0)

  # 跳過 INDEX, _MOC, 明顯有內容的
  if [[ "$name" == "INDEX.md" || "$name" == "_MOC.md" || "$name" == "_index.md" || "$name" == "README.md" ]]; then
    continue
  fi

  if [[ "$lines" -ge 9 && "$lines" -le 25 ]]; then
    content=$(head -30 "$f" 2>/dev/null)
    prompt="你是 Obsidian Vault 整理助手。以下是一個 markdown 檔案的內容。
判斷這個檔案是否為「廢檔」（空殼、無實質內容、只有標題沒有正文、自動生成但無資料）。

回答格式只能是以下兩種之一：
WASTE: [一行說明原因]
KEEP: [一行說明有什麼內容值得保留]

檔案名稱：$name
---
$content"

    verdict=$(echo "$prompt" | gemini 2>/dev/null | head -3)
    if echo "$verdict" | grep -q "^WASTE"; then
      echo "- \`$f\`" >> "$REPORT"
      echo "  - Gemini: $verdict" >> "$REPORT"
    fi
    sleep 0.5
  fi
done

echo "" >> "$REPORT"
echo "---" >> "$REPORT"
echo "腳本完成" >> "$REPORT"

echo "報告已輸出到：$REPORT"
