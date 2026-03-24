---
name: morning-brief
description: 每天早上自動整合行事曆、昨日 log、待處理清單，生成 150 字晨報推送 Telegram。使用時機：早報、晨報、今天計劃、早安、今天有什麼。
---

# Morning Brief — 每日早報

## Overview

掃行事曆 + 昨日 log + 待處理清單 → 組 150 字晨報 → 推 Telegram。
每天 07:30 自動跑，也可手動觸發。

## Step 1：取今日行程

```bash
gog calendar events primary \
  --from "$(date -u +%Y-%m-%dT00:00:00Z)" \
  --to "$(date -u +%Y-%m-%dT23:59:59Z)" \
  --json 2>/dev/null
```

無行程 → 標注「今天空班」，繼續執行不報錯。
API 失敗 → 標注「⚠️ 行程查詢失敗」，繼續執行。

## Step 2：取昨日日摘要

```bash
DAILY_DIR="$HOME/.claude/projects/-Users-Modema11434-Documents-Life-OS/daily"
MONTHLY="$DAILY_DIR/$(date +%Y-%m).md"
YESTERDAY=$(date -v-1d +%Y-%m-%d)   # macOS

awk "/^### $YESTERDAY 日摘要/{found=1} found{print; if(/^---$/)exit}" "$MONTHLY" 2>/dev/null
```

昨日摘要不存在 → 靜默略過，不報錯。

## Step 3：取待處理清單（前 3 項）

讀 MEMORY.md「⏳ 待處理」區塊，取前 3 筆。

```bash
MEMORY="$HOME/.claude/projects/-Users-Modema11434-Documents-Life-OS/memory/MEMORY.md"
awk '/^## ⏳ 待處理/{found=1; next} found && /^##/{exit} found && /^[0-9]/{print; count++} count==3{exit}' "$MEMORY"
```

## Step 4：組合晨報並推送

將以上三份資料整合，寫 150 字以內繁體中文晨報：

```
🌅 YYYY-MM-DD（週X）早安

📅 今日行程
• HH:MM — 事項
（無事項：今天空班）

📋 昨日未竟
• 一句話（若有）

⚡ 最重要的事
1. 待處理第 1 項
2. 待處理第 2 項
3. 待處理第 3 項
```

用 mcp__plugin_telegram_telegram__reply 推送，chat_id 從對話取得，不加 reply_to（主動推送）。

## 備註

- 行程超過 5 筆 → 只列前 5 筆，標注「共 N 個行程」
- 全報嚴格 150 字以內，寧可截斷也不超字
- Cron 自動觸發：每天 07:30（透過 schedule skill 設定）
- 手動觸發：用戶說「早報」「晨報」「今天計劃」「早安」立即執行
