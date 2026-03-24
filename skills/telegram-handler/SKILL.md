---
name: telegram-handler
description: 每次收到 Telegram 訊息時的標準前置處理。建立時間覺察與上下文感知，結果只供內部使用，不回報給用戶。使用時機：所有 Telegram 訊息到達時自動執行。
---

# Telegram Handler — 時間覺察前置處理

## Overview

Telegram 訊息到 → 讀系統時間 → 換算台灣時間 → 計算間隔 → 建立內部 context → 再回應。
結果**不回報給用戶**，只影響我的判斷。

## Step 1：讀取時間資訊

```bash
# 當下系統時間（UTC）
NOW_EPOCH=$(date +%s)
NOW_UTC=$(date -u +"%Y-%m-%d %H:%M")

# 台灣時間（UTC+8）
TW_HOUR=$(date -u +%H)
TW_EPOCH=$((NOW_EPOCH + 28800))
TW_TIME=$(date -u -r $TW_EPOCH +"%H:%M" 2>/dev/null || date -u -d "@$TW_EPOCH" +"%H:%M")

# 從 Telegram channel tag 的 ts 欄位取訊息時間
MSG_TS="$1"   # 格式：2026-03-24T00:06:02.000Z
MSG_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${MSG_TS%.000Z}" +%s 2>/dev/null || \
            date -d "${MSG_TS%.000Z}Z" +%s)

# 計算間隔
GAP_MIN=$(( (NOW_EPOCH - MSG_EPOCH) / 60 ))
```

## Step 2：判斷時段

| 台灣時間 | 時段 | 含義 |
|---------|------|------|
| 06:00–09:00 | 早晨 | 剛起床 |
| 09:00–12:00 | 上午 | 工作時段 |
| 12:00–14:00 | 午間 | 可能在吃飯 |
| 14:00–18:00 | 下午 | 工作時段 |
| 18:00–22:00 | 晚間 | 可能在休息 |
| 22:00–02:00 | 深夜 | 應該要睡了 |
| 02:00–06:00 | 凌晨 | 熬夜狀態 |

## Step 3：建立內部 context（不輸出）

從以上資訊得到：
- 台灣現在幾點（時段判斷）
- 訊息是幾分前傳的（是否有延遲）
- 距上次訊息間隔多久（是新 session 還是連續對話）

這些 context 內化，用來：
- 判斷用戶可能的狀態（剛起床、在工作、熬夜）
- 語氣微調（凌晨不說「早安」）
- 不問重複的問題（間隔很久 → 可能需要重新同步 context）

## 備註

- **不回報時間資訊給用戶**，只影響內部判斷
- 台灣時間 = Telegram ts（UTC）+ 8 小時
- 訊息延遲、間隔時長：自己知道就好，不說出來
- 時段判斷用於語氣，不用於功能開關
