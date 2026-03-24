---
name: triad-tools
description: 三大金剛派工路由：判斷任務應該交給 Gemini CLI（one-shot 內容）、Codex CLI（工程任務）還是 Claude Code（長流程重構），並提供標準派工模板。使用時機：三大金剛、派工、委派、叫阿普、交給三大金剛、用 gemini、用 codex、本地算力分攤。
---

# 三大金剛派工（Triad Tools）

## Overview

三個金剛各有所長，路由到對的工具，不浪費算力。

## 快速判斷

| 金剛 | 選它當 | 不選它當 |
|------|--------|---------|
| **Gemini CLI** | one-shot 摘要/改寫/清單/JSON輸出 | 需要改檔落地 |
| **Codex CLI** | 理解 repo、產生 patch、code review | 長流程多輪迭代 |
| **Claude Code** | 跨多檔重構、改碼→測試→迭代 | 快速 one-shot |

**硬規則**：一兩行小修 → 直接 edit，不派工。

## 派工模板

### Gemini（one-shot）

```bash
gemini "<prompt>"
gemini --output-format json "<prompt>"
```

### Codex（工程，限定目錄）

```bash
# 互動
codex -C <dir> --no-alt-screen

# 一次性
codex exec -C <dir> "<prompt>"
```

### Claude Code（長流程）

```bash
# 在 repo workdir 啟動
claude
# 先要求 plan（改哪些檔、跑什麼測試）再動手
```

## 派工標準作業

1. **鎖工作目錄**：只在目標資料夾內跑
2. **留痕**：`stdout/stderr | tee logs/<task>.log`
3. **互動開 PTY**：Codex/Claude Code 用 `pty:true`
4. **能沙盒就沙盒**（Codex）：`--sandbox --ask-for-approval`

## Life-OS 算力分配

| 機器 | 角色 | 用途 |
|------|------|------|
| 德瑪（Mac mini M4 Pro） | 主力 | Claude Code 長流程 |
| 小蝦（辦公室機） | 客服 | LINE@ 自動回覆 |
