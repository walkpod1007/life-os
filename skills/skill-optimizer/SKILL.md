---
name: skill-optimizer
description: 分析過去對話紀錄，找出重複的摩擦點，提出 SKILL.md 和 CLAUDE.local.md 的具體優化建議。使用時機：系統優化、skill 有問題、哪個 skill 要改、對話分析、改善建議、自我優化。
---

# Skill Optimizer — 對話歷史分析與自我優化

## Overview

讀 daily session log → 找重複摩擦點 → 分析哪些 skill 有問題 → 輸出具體改法。
與 insight 不同：insight 看「你的生活模式」，skill-optimizer 看「AI 系統本身的問題」。

## Step 1：讀取最近 14 天 session log

```bash
DAILY_DIR="$HOME/.claude/projects/-Users-Modema11434-Documents-Life-OS/daily"
MONTHLY="$DAILY_DIR/$(date +%Y-%m).md"
LAST_MONTH="$DAILY_DIR/$(date -v-1m +%Y-%m).md"   # macOS

# 讀本月 + 上月（月初時）
cat "$LAST_MONTH" "$MONTHLY" 2>/dev/null | tail -2000
```

## Step 2：AI 分析 — 找系統摩擦點

讀完 log 後，專注分析：

### 問題維度 1：Skill 失效
- 哪個 skill 被用了但沒有正確執行？
- 用戶說「不對」「再試一次」「你理解錯了」的次數？
- 哪個 skill 的觸發詞不夠精確？

### 問題維度 2：重複解釋
- 哪些事情用戶說了超過 2 次？（表示 CLAUDE.local.md 沒記錄）
- 哪些 context 每次都要重新交代？

### 問題維度 3：遺漏的自動化
- 哪些重複性請求還沒有對應的 skill？
- 哪些手動流程可以做成 cron 自動跑？

### 問題維度 4：Skill 內容過時
- 哪些 skill 的 bash 指令失敗過？
- 哪些 skill 描述跟實際用法不符？

## Step 3：產出優化建議

格式：

```
# Skill Optimizer 報告 — YYYY-MM-DD

## 需要修改的 Skill（依優先級）

🔴 立刻改
- skill-name：問題描述 → 建議修改方向

🟡 這週改
- skill-name：問題描述 → 建議修改方向

## 需要新增到 CLAUDE.local.md 的 context

- 「用戶反覆說明的 X」→ 加到 CLAUDE.local.md 的「工作 context」段落

## 建議新增的 Skill

- 功能描述（用戶重複做了 N 次的手動操作）

## 可以做成自動化的流程

- 重複操作 → 建議 cron 時間和指令
```

## Step 4：存檔 + 推 Telegram

報告存到：
```bash
REPORT="$HOME/.claude/projects/-Users-Modema11434-Documents-Life-OS/daily/$(date +%Y-%m).md"
# 追加到月檔
```

Telegram 推送前 300 字摘要 + 「說『展開優化報告』看全部」。

## 備註

- 不自動修改任何 skill 或 CLAUDE.local.md，只輸出建議
- 修改前必須讓用戶確認（「要現在改 X 嗎？」）
- 與 insight 分工：insight = 用戶生活模式；skill-optimizer = AI 系統本身
- 建議每 2 週跑一次，或用戶明顯感覺「AI 愈來愈不好用」時立即跑
