---
name: loop-manager
description: 列出、啟動、暫停所有 /loop 任務，查看心跳狀態。觸發詞：心跳狀態、loop 清單、暫停心跳、停止心跳、啟動心跳、有哪些心跳在跑
---

# 心跳管理員

## 概述

管理 Life-OS 所有定時 /loop 任務的生命週期，讓你在 Telegram 一眼看清哪些心跳在跑、哪些已停止。支援列出、啟動、暫停單一或全部任務。

## 指令對照

| 用戶說 | 動作 |
|--------|------|
| 心跳狀態 / loop 清單 | 列出所有 loop（Step 1） |
| 暫停心跳 `<名稱>` | 刪除指定 cron（Step 3） |
| 停止所有心跳 | 刪除全部 loop cron（Step 3） |
| 啟動心跳 `<名稱>` | 新增 cron（Step 2） |

---

## 步驟

### Step 1：列出所有心跳

呼叫 CronList 工具，取得所有 cron 項目，過濾出 `/loop` 類型的任務。

每筆資料顯示：
- **名稱**（cron ID 或備註）
- **排程**（`*/10 * * * *` → 每 10 分鐘）
- **上次執行**（若有）
- **狀態**：🟢 執行中 / 🔴 已停止

格式範例（回傳給 Telegram）：

```
🫀 心跳狀態 — 2026-03-24 14:00

🟢 morning-brief      每天 07:00
🟢 intel-digest       每 30 分鐘
🔴 week-push          週日 09:00（已停止）

共 3 個任務，2 個執行中。
```

若沒有任何 loop 任務：

```
🫀 目前沒有心跳在跑。
說「啟動心跳 <名稱>」來新增。
```

---

### Step 2：啟動心跳

用戶說「啟動心跳 `<名稱>`」或「新增 loop `<名稱>`」時：

1. 確認該 loop skill 的 SKILL.md 是否存在：

```bash
ls /Users/Modema11434/Documents/Life-OS/skills/<名稱>/SKILL.md
```

2. 詢問排程（若用戶未指定）：
   - 預設提供選項：`每 10 分鐘 / 每 30 分鐘 / 每小時 / 每天 HH:MM`

3. 呼叫 CronCreate 工具，設定對應排程與指令。

4. Telegram 回報：

```
✅ <名稱> 心跳已啟動
排程：每 30 分鐘
下次執行：14:30
```

---

### Step 3：暫停 / 刪除心跳

用戶說「暫停心跳 `<名稱>`」或「停止 loop `<名稱>`」時：

1. 呼叫 CronList 找到對應 ID。
2. 呼叫 CronDelete 刪除該 cron。
3. Telegram 回報：

```
⏸️ <名稱> 心跳已暫停。
說「啟動心跳 <名稱>」可重新啟動。
```

用戶說「停止所有心跳」時，逐一刪除全部 loop cron，最後統一回報數量。

---

## 備註

- **只操作 /loop 類型的 cron**，不要碰 `23:30 daily-log`、`03:00 weekly-insight` 等系統 cron。
- CronList / CronCreate / CronDelete 是 Claude Code 內建工具，直接呼叫，不需要 bash。
- Telegram 回報用 reply 工具，訊息保持簡短（5 行以內）。
- 若 CronCreate 失敗（排程格式錯誤），告知用戶正確格式並再次詢問。
- loop 任務命名規則：與 skill 目錄名稱一致（如 `morning-brief`、`intel-digest`）。
