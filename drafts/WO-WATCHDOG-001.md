---
id: WO-WATCHDOG-001
title: Claude Code 看門狗自動重啟機制
status: ready
priority: medium
created: 2026-03-24
---

# WO-WATCHDOG-001：Claude Code 看門狗重啟

## 背景

Claude Code 無法直接讀 token 數，用「session 時間」代替（90 分鐘 ≈ 上限）。
觸發後：Claude 寫 MEMORY.md → exit → supervisor 自動重啟（帶 Telegram channel）。

## 已完成

- [x] `~/.claude/hooks/watchdog-check.sh` — PreToolUse hook，偵測 flag 後 block 工具並提示 Claude 寫交接卡
- [x] `~/.claude/hooks/session-start-ts.sh` — SessionStart hook，記錄啟動時間
- [x] `~/.claude/vault-watchdog.sh` — 計時腳本，超過 90 分鐘寫 reset.flag

## 待完成

- [ ] **1. 接線 settings.json**
  - 加入 `SessionStart` hook → `session-start-ts.sh`
  - 修改 `PreToolUse` hook：現有 rtk-rewrite.sh 後串接 watchdog-check.sh

- [ ] **2. supervisor 腳本** `~/.claude/claude-supervisor.sh`
  - 迴圈：執行 claude → 偵測 exit → sleep 3 → 重啟
  - 重啟指令：`cd ~/Documents/Life-OS && claude --channels plugin:telegram@claude-plugins-official`
  - 加 `--no-supervisor` flag 可手動停止

- [ ] **3. cron 加入 watchdog**
  - `*/5 * * * * bash ~/.claude/vault-watchdog.sh`

- [ ] **4. 把 claude 改為從 supervisor 啟動**
  - 測試：手動跑 `~/.claude/claude-supervisor.sh`
  - 確認 reset 流程全跑通

## 測試方法

```bash
# 手動觸發測試（不用等 90 分鐘）
touch ~/.claude/reset.flag
# 然後在 Claude Code 裡隨便下一個工具指令，應該看到 WATCHDOG 訊息
```
