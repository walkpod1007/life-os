---
name: notebooklm-query
description: 查詢 NotebookLM 筆記本，根據已匯入的來源回答問題（零幻覺）。
status: stable
version: 1.0.0
author: Claude Code (阿普)
triggers:
  - "查筆記本"
  - "問 nbLM"
  - "查 AI"
  - "查科技"
  - "查寶可夢"
  - "查電影"
  - "查性別"
  - "notebooklm query"
  - "nbLM 查"
metadata:
  openclaw:
    emoji: "🔎"
    category: integration
    tags: ["notebooklm", "query", "knowledge-base", "research"]
    requires:
      bins: ["python3"]
      files: ["/Users/Modema11434/Documents/New project/.venv/bin/notebooklm"]
    health:
      smokeTests:
        - id: "cli-check"
          command: "/Users/Modema11434/Documents/New\\ project/.venv/bin/notebooklm auth check --test"
          success: "exit=0"
          tolerance: "warn"
---

# NotebookLM Query

查詢 NotebookLM 筆記本中的知識庫。所有回答基於已匯入的來源，零幻覺。

## When to use (trigger phrases)

- 「查 AI」「查科技」「查寶可夢」「查電影」「查性別」
- 「問筆記本」「nbLM 查」
- 用戶想從已收集的 YouTube/Podcast 摘要中查資料

## 主題筆記本對照

| 主題 | Notebook ID | 觸發詞 |
|------|------------|--------|
| AI 人工智慧 | 792393f8-589e-425a-a971-44ff329d6f3c | 查 AI |
| 科技 Tech | （待建） | 查科技 |
| 寶可夢 Pokémon | （待建） | 查寶可夢 |
| 電影影評 Movies | （待建） | 查電影 |
| 性別議題 Gender | （待建） | 查性別 |

## Quick start

```bash
NBLM="/Users/Modema11434/Documents/New project/.venv/bin/notebooklm"

# 1. 選擇筆記本（用 ID 前幾碼即可）
$NBLM use 792393f8

# 2. 查詢
$NBLM ask "請用 800 字告訴我最近的 AI 趨勢"

# 3. 列出來源
$NBLM source list

# 4. 查看對話紀錄
$NBLM history
```

## 參數

| 指令 | 說明 |
|------|------|
| `use <id>` | 切換到指定筆記本 |
| `ask "問題"` | 查詢當前筆記本 |
| `history` | 查看對話紀錄 |
| `source list` | 列出所有來源 |
| `list` | 列出所有筆記本 |

## 運作原理

1. 用戶提問 → 判斷主題 → 切換到對應筆記本
2. 透過 notebooklm-py 送出查詢
3. NotebookLM 基於已匯入的來源回答（附引用編號）
4. 回傳答案給用戶

## 注意

- 查詢不消耗任何 API token（NotebookLM 免費）
- 回答品質取決於已匯入的來源數量和品質
- 登入狀態存在 `~/.notebooklm/storage_state.json`，過期需重新 login
