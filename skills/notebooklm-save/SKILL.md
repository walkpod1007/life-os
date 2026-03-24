---
name: notebooklm-save
description: 將 NotebookLM 查詢結果存成 .md 檔案到 Vault。
status: stable
version: 1.0.0
author: Claude Code (阿普)
triggers:
  - "存起來"
  - "存到筆記"
  - "存到 Vault"
  - "save note"
  - "nbLM 存"
metadata:
  openclaw:
    emoji: "💾"
    category: integration
    tags: ["notebooklm", "save", "vault", "export"]
    requires:
      bins: ["python3"]
      files: ["/Users/Modema11434/Documents/New project/.venv/bin/notebooklm"]
    health:
      smokeTests:
        - id: "cli-check"
          command: "test -f /Users/Modema11434/Documents/New\\ project/.venv/bin/notebooklm",
          success: "exit=0"
          tolerance: "none"
---

# NotebookLM Save

將 NotebookLM 的查詢結果匯出為 .md 檔案，存到 Vault 對應位置。

## When to use (trigger phrases)

- 查詢完 NotebookLM 後，用戶說「存起來」「存到筆記」
- 需要把 NotebookLM 的回答保存到 Vault 供離線參考

## Quick start

```bash
NBLM="/Users/Modema11434/Documents/New project/.venv/bin/notebooklm"
VAULT="/Users/Modema11434/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault"

# 1. 在 NotebookLM 內存為筆記
$NBLM history --save

# 2. 列出筆記
$NBLM note list

# 3. 匯出指定筆記到 Vault
$NBLM note get <note_id> > "$VAULT/30_Knowledge/01_AI_Tech/nbLM-查詢結果.md"
```

## 存放位置規則

| 主題 | Vault 路徑 |
|------|-----------|
| AI 人工智慧 | `30_Knowledge/01_AI_Tech/` |
| 科技 Tech | `30_Knowledge/01_AI_Tech/` |
| 寶可夢 Pokémon | `30_Knowledge/02_Books_Ideas/` |
| 電影影評 Movies | `30_Knowledge/02_Books_Ideas/` |
| 性別議題 Gender | `30_Knowledge/02_Books_Ideas/` |

## 命名慣例

```
YYYY-MM-DD-nbLM-{主題}-{摘要}.md
例：2026-03-23-nbLM-AI-八集節目趨勢摘要.md
```

## 運作流程

1. 用戶說「存起來」
2. 取得當前筆記本的最新對話
3. 格式化為 Markdown（含標題、來源引用、日期）
4. 存到 Vault 對應的 30_Knowledge/ 子目錄
5. 回覆確認訊息

## 注意

- 只存最後一次查詢結果，不是整本筆記本
- 存檔不影響 NotebookLM 內的資料
- 存到 Vault 後可被 Obsidian 搜尋和引用
