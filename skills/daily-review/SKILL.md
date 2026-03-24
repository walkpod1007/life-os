---
name: daily-review
description: 早晨一鍵啟動：整合 Google Calendar 今日行程 + Gmail 未讀信件 + Life OS 待處理清單，產出精簡的今日作戰計劃。使用時機：早安、開始今天、今天怎麼安排、daily review、今日總覽、今天有什麼。
---

# Daily Review

## Overview

整合行程、信件、待辦，60 秒掌握全局。

## 執行流程

1. 查今日行程：`gog calendar events primary --from <today 00:00> --to <today 23:59> --json`
2. 查未讀信件：`gog gmail search 'is:unread newer_than:1d' --max 10`
3. 讀 MEMORY.md 的「待處理」清單，取前 3 項
4. 整合輸出

## 輸出格式

```
🌅 今天 YYYY-MM-DD（週X）

📅 行程
• HH:MM — 事項
（無事項：「今天空班」）

📧 需要回覆
• [寄件人] 主旨 — 一句話說要做什麼
（無緊急信件略過）

⚡ 待處理
• 最重要的 3 項

💡 今天重點
• 一句話：今天最重要的一件事
```

## 原則

- 總輸出不超過 20 行
- 行程用 24 小時制
- 未讀信件只列需要行動的，通知類跳過
- 語氣輕鬆，不要正式報告感
