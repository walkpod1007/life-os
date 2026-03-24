---
name: daily-log
description: 手動觸發今日日誌摘要。讀取今天的 session 冷儲存紀錄，用 AI 寫 80-100 字摘要追加進月檔。使用時機：用戶說「/daily-log」「寫今天的日誌」「記錄一下今天」「今天的摘要」。
---

# Daily Log — 手動觸發日摘要

## 日誌架構

```
~/.claude/projects/-Users-Modema11434-Documents-Life-OS/daily/
  2026-03.md  ← 月一檔，自動追加
  2026-04.md
```

Session 冷儲存：每次 session 結束由 SessionEnd hook 自動寫入（0 token）。
日摘要：由本 skill 或 cron 腳本觸發（需少量 token）。

## 執行步驟

**Step 1：確認今天有沒有 session 紀錄**

```bash
DAILY_DIR="$HOME/.claude/projects/-Users-Modema11434-Documents-Life-OS/daily"
MONTHLY="$DAILY_DIR/$(date +%Y-%m).md"
TODAY=$(date +%Y-%m-%d)

grep "^## $TODAY" "$MONTHLY" 2>/dev/null && echo "有紀錄" || echo "今天沒有 session 冷儲存"
```

**Step 2：讀取今日所有 session 條目**

從月檔中擷取今天的所有 `## YYYY-MM-DD HH:MM` 區塊。

**Step 3：AI 生成摘要**

用今天的 session 訊息清單，寫 80-100 字繁體中文日誌：
- 今天做了什麼
- 完成了什麼
- 有什麼沒做完

格式：一段純文字，不加標題，口語化，像個人日記。

**Step 4：追加進月檔**

```
### YYYY-MM-DD 日摘要
（摘要內容）

---
```

**Step 5：Telegram 回報**

簡短告知「日誌已寫，今天 N 個 session」。

## Cron 自動觸發

每天 23:30 自動跑：

```bash
# crontab -e
30 23 * * * bash /Users/Modema11434/.openclaw/workspace/scripts/daily-summary.sh
```
