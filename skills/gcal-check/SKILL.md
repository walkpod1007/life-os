---
name: gcal-check
description: 查詢 Google Calendar 行程，支援今天、明天、本週、指定日期，判斷是否有空。使用時機：今天行程、本週行程、幾點有事、有什麼行程、行程查詢、這週有什麼、下午有空嗎。
---

# Google Calendar Check

## Overview

快速查行程，不廢話。用 `gog` CLI 直接查 Google Calendar。

## 時間範圍判斷

| 用戶說 | 查詢範圍 |
|--------|---------|
| 今天 | 今天 00:00~23:59 |
| 明天 | 明天 00:00~23:59 |
| 本週 | 本週一~週日 |
| 下午有空嗎 | 今天 13:00~18:00 |
| 具體日期 | 那一天 |
| 沒說 | 預設今天 |

## 指令

```bash
# 今天
gog calendar events primary \
  --from "$(date -u +%Y-%m-%dT00:00:00Z)" \
  --to "$(date -u +%Y-%m-%dT23:59:59Z)" \
  --json

# 本週（週一~週日）
gog calendar events primary --from <monday-iso> --to <sunday-iso> --json

# 查多個日曆
gog calendar list   # 先列出所有日曆 ID
```

## 輸出格式

```
📅 YYYY-MM-DD（週X）行程

HH:MM — 事項（地點）
HH:MM — 事項（💻 視訊）
🗓 全天 — 全天活動

共 N 個行程
```

無行程：「今天空班。」
