---
name: insight
description: 系統自我優化回顧。讀取最近 7-30 天的 daily session 日誌，找出重複摩擦點、未完成的事項、可以改善的模式，產出改進提案。使用時機：用戶說「/insight」「週回顧」「系統回顧」「看看上週」「有什麼可以改的」。
---

# Insight — 系統自我優化回顧

## 日誌來源

```
DAILY_DIR=~/.claude/projects/-Users-Modema11434-Documents-Life-OS/daily/
月檔格式：YYYY-MM.md（每 session 一個 ## 區塊 + 每天一個日摘要）
```

## Step 1：讀取日誌

```bash
DAILY_DIR="$HOME/.claude/projects/-Users-Modema11434-Documents-Life-OS/daily"

# 讀取本月 + 上月（如果在月初）
ls "$DAILY_DIR"/*.md 2>/dev/null | sort -r | head -2
```

讀取最近 N 天的內容（預設 7 天，用戶可指定 14/30）。

## Step 2：AI 分析

讀完日誌後，分析以下維度：

### 摩擦點（反覆出現的問題）
- 哪些事情被問了超過一次？
- 哪些工具或流程一直出錯？
- 哪些任務一直被推遲？

### 未完成的事
- 有哪些任務開始了但沒有結論？
- 有哪些「之後再做」但一直沒做的？

### 使用模式
- 哪些 skill 最常被用？
- 哪些請求可以做成 skill 或自動化？
- CLAUDE.md 或 MEMORY.md 有沒有需要更新的地方？

## Step 3：產出報告並存入月檔

報告追加到當月月檔（永久保存）：

```
### 週回顧 YYYY-MM-DD

**摩擦點（重複出現的問題）**
1. ...

**未完成的事**
- ...

**可以自動化的地方**
- ...

**建議動作**
🔴 立刻做：...
🟡 這週做：...
⚪ 有空做：...
```

同時透過 Telegram 回覆摘要（前 3 條建議）。

## Step 4：問用戶要不要執行

列出優先度最高的 1-2 個建議，問「要現在處理嗎？」

## 保留機制

- 月檔（YYYY-MM.md）**永久保存**，不清除（終身紀錄）
- 自動觸發：週日 03:00 由 weekly-insight.sh 跑
- 手動觸發：說「/insight」隨時可跑
