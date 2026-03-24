---
name: podcast-grabber
status: stable
description: 抓取 Podcast（RSS/Spotify/Apple），產出 NotebookLM-ready 的 Markdown 摘要包
version: 1.0.0
author: GPT Codex
triggers:
  - "抓 Podcast"
  - "抓播客"
  - "podcast grab"
  - "podcast sync"
  - "新集數"
metadata:
  openclaw:
    emoji: "🎙️"
    category: tool
    tags: ["podcast", "rss", "spotify", "summary", "notebooklm"]
    requires:
      bins: ["python3", "node"]
      files: ["/Users/Modema11434/Documents/New project/podcast_notebook_pipeline.py"]
    install:
      - id: "node-deps"
        kind: "shell"
        command: "cd '/Users/Modema11434/Documents/New project' && npm install"
        label: "Install Node dependencies (playwright-core)"
    health:
      smokeTests:
        - id: "script-exists"
          command: "test -f /Users/Modema11434/Documents/New\\ project/podcast_notebook_pipeline.py"
          success: "exit=0"
          tolerance: "none"
        - id: "sync-script-exists"
          command: "test -f /Users/Modema11434/Documents/New\\ project/podcast_sync.py"
          success: "exit=0"
          tolerance: "none"
---

# Podcast Grabber

抓取 Podcast 節目（支援 RSS feed、Spotify、Apple Podcasts），產出結構化 Markdown 摘要，可直接匯入 NotebookLM。

## 兩種模式

### 1. 單次抓取（podcast_notebook_pipeline.py）

輸入一個 Podcast URL，抓取所有或指定數量的集數。

### 2. 增量同步（podcast_sync.py）

輪詢設定好的 feed 清單，只抓新集數，自動匯入 NotebookLM。

## 輸入

- Podcast RSS feed URL
- Spotify show/episode URL
- Apple Podcasts URL

## 產出

| 檔案 | 說明 |
|------|------|
| `manifest.json` | 完整 metadata（集數清單、batch 配置） |
| `import-plan.md` | NotebookLM 匯入計畫 |
| `overview/show-overview.md` | 節目總覽 |
| `batches/batch-XXX/batch-summary.md` | 每批摘要 |
| `batches/batch-XXX/episodes/*.md` | 每集摘要 |

## 產出存放位置

`50_Research/` 或 `30_Knowledge/`（依主題歸類）

## 用法

### 單次抓取

```bash
cd "/Users/Modema11434/Documents/New project"

# 基本用法（RSS feed）
.venv/bin/python podcast_notebook_pipeline.py "https://feeds.example.com/podcast.xml"

# Spotify URL
.venv/bin/python podcast_notebook_pipeline.py "https://open.spotify.com/show/xxxxx"

# 限制集數
.venv/bin/python podcast_notebook_pipeline.py URL --max-episodes 10

# 指定輸出目錄
.venv/bin/python podcast_notebook_pipeline.py URL --output-dir /path/to/output

# 指定 RSS 國家（影響 iTunes 查詢）
.venv/bin/python podcast_notebook_pipeline.py URL --rss-country tw
```

### 增量同步

```bash
cd "/Users/Modema11434/Documents/New project"

# 同步所有已設定的 feed（偵測新集數、自動匯入）
.venv/bin/python podcast_sync.py

# 指定 feed 設定檔
.venv/bin/python podcast_sync.py --feeds inbox/podcast-feeds.json

# 每個 feed 最多抓 3 集新的
.venv/bin/python podcast_sync.py --max-new 3
```

### Feed 設定檔格式（podcast-feeds.json）

```json
{
  "feeds": [
    {
      "name": "節目名稱",
      "url": "https://feeds.example.com/podcast.xml",
      "rss_country": "tw",
      "headless": true
    }
  ]
}
```

位置：`/Users/Modema11434/Documents/New project/inbox/podcast-feeds.json`

## 參數

### podcast_notebook_pipeline.py

| 參數 | 預設 | 說明 |
|------|------|------|
| `url` | （必填） | Podcast URL（RSS/Spotify/Apple） |
| `--output-dir` | `output` | 輸出目錄 |
| `--batch-size` | 44 | 每個 NotebookLM notebook 的集數 |
| `--max-episodes` | 無限 | 最多處理幾集 |
| `--rss-country` | `tw` | iTunes RSS 查詢國家碼 |

### podcast_sync.py

| 參數 | 預設 | 說明 |
|------|------|------|
| `--feeds` | `inbox/podcast-feeds.json` | Feed 設定檔 |
| `--state` | `inbox/podcast-sync-state.json` | 同步狀態檔 |
| `--output-dir` | `output_podcast_sync` | 輸出目錄 |
| `--max-new` | 5 | 每個 feed 最多抓幾集新的 |

## 搭配 NotebookLM 匯入

```bash
# 批量匯入
node scripts/notebooklm-import-all.js --manifest /path/to/manifest.json --include-overview --headless

# 單一 Podcast 一鍵匯入
node scripts/run-podcast-to-notebooklm.js
```

## 腳本位置

```
/Users/Modema11434/Documents/New project/
├── podcast_notebook_pipeline.py     ← 主腳本（單次抓取）
├── podcast_sync.py                  ← 增量同步
├── inbox/
│   ├── podcast-feeds.json           ← Feed 清單設定
│   └── podcast-sync-state.json      ← 同步狀態（自動維護）
├── scripts/
│   ├── notebooklm-import-all.js     ← 批量匯入 NotebookLM
│   └── run-podcast-to-notebooklm.js ← 一鍵匯入
├── requirements.txt                 ← Python 依賴
└── package.json                     ← Node 依賴（playwright-core）
```
