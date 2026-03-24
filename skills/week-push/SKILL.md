---
name: week-push
description: 週日自動執行 insight 並將週回顧結果推送到 Telegram。觸發詞：週報、週回顧、這週怎麼樣
---

# 週回顧推送

## 概述

包裝 insight skill，執行週回顧分析後，將重點摘要（300 字以內）主動推送到 Telegram。
適合每週日 03:00 由 cron 自動觸發，也可手動呼叫。

## 步驟

### Step 1：執行 insight 週回顧

呼叫 insight skill，讀取最近 7 天的日誌，產出完整週回顧報告（包含摩擦點、未完成事項、建議動作）。

> 詳細分析邏輯見 `skills/insight/SKILL.md`。

### Step 2：擷取推送摘要

從 insight 報告中取出以下段落，合計不超過 300 字：

```
📊 週回顧 YYYY-MM-DD（第 N 週）

🔴 立刻做：<最高優先項>
🟡 這週做：<次優先項>
⚪ 有空做：<低優先項>

💡 本週摘要：<1-2 句最關鍵發現>
```

字數超過 300 字時，只保留「立刻做」和「本週摘要」，其餘截斷。

### Step 3：透過 Telegram 推送

使用 `mcp__plugin_telegram_telegram__reply` 推送摘要，不使用 `reply_to`（主動推送，非回覆）。

```
chat_id: 從 .mcp.json 或環境變數取得（telegram 預設 chat_id）
text: <Step 2 產出的摘要>
```

推送完成後在 terminal 輸出：`✅ 週回顧已推送 Telegram`

## 備註

- **自動觸發**：週日 03:00 cron（配合 insight 的 `weekly-insight.sh`）
- **手動觸發**：說「週報」「週回顧」「這週怎麼樣」即可啟動
- **Telegram 回報限制**：Bot API 單則訊息上限 4096 字元，300 字遠低於上限，不需分割
- **無日誌時**：若 daily 目錄無近 7 天資料，推送「本週無日誌，無法產出週回顧」並結束
- **不重複推送**：同一天若已推送過（月檔含 `週回顧 YYYY-MM-DD`），跳過並提示已完成
