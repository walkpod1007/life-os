#!/usr/bin/env bash
# vault-trash-move.sh
# 把 waste-report.md 裡的廢檔移到 _trash/，而非直接刪除
# 用法：bash vault-trash-move.sh [report_path]

VAULT="/Users/Modema11434/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault"
TRASH="$VAULT/_trash"
REPORT="${1:-/Users/Modema11434/Documents/Life-OS/scripts/waste-report.md}"

mkdir -p "$TRASH"

# 只抓 WASTE 區（確定廢檔 + Gemini 判定廢檔），跳過 KEEP 區
in_keep=0
moved=0
skipped=0

while IFS= read -r line; do
  # 偵測進入 KEEP 區
  if echo "$line" | grep -q "Gemini 判定保留"; then
    in_keep=1
  fi

  # 如果在 KEEP 區就跳過
  [ "$in_keep" -eq 1 ] && continue

  # 提取路徑
  rel=$(echo "$line" | sed -n "s/^- \`\(.*\)\` —.*/\1/p")
  [ -z "$rel" ] && continue

  full="$VAULT/$rel"
  if [ -f "$full" ]; then
    # 保留原始相對路徑結構，避免同名衝突
    dest="$TRASH/$(echo "$rel" | tr '/' '_')"
    mv "$full" "$dest" && echo "🗑️  → _trash: $rel" && ((moved++))
  else
    echo "⚠️  找不到（已刪？）：$rel" && ((skipped++))
  fi
done < "$REPORT"

echo ""
echo "完成：移到 _trash $moved 個，找不到 $skipped 個"
echo "確認後執行 'rm -rf \"$TRASH\"' 才真正刪除"
