---
name: youtube-grabber
status: stable
description: 抓取 YouTube 頻道/播放清單/影片，產出 NotebookLM-ready 的 Markdown 摘要包
version: 1.0.0
author: GPT Codex
triggers:
  - "抓 YouTube"
  - "抓 YT"
  - "youtube grab"
  - "yt grab"
  - "抓頻道"
  - "抓播放清單"
metadata:
  openclaw:
    emoji: "📺"
    category: tool
    tags: ["youtube", "transcript", "summary", "notebooklm"]
    requires:
      bins: ["python3", "yt-dlp"]
      files: ["/Users/Modema11434/Documents/New project/yt_notebook_pipeline.py"]
    install:
      - id: "yt-dlp"
        kind: "brew"
        formula: "yt-dlp"
        bins: ["yt-dlp"]
        label: "Install yt-dlp via Homebrew"
      - id: "pip-deps"
        kind: "pip"
        package: "yt-dlp youtube-transcript-api"
        bins: ["yt-dlp"]
        label: "Install Python dependencies"
    health:
      smokeTests:
        - id: "yt-dlp-check"
          command: "command -v yt-dlp"
          success: "exit=0"
          tolerance: "none"
        - id: "script-exists"
          command: "test -f /Users/Modema11434/Documents/New\\ project/yt_notebook_pipeline.py"
          success: "exit=0"
          tolerance: "none"
---

# YouTube Grabber

抓取 YouTube 頻道、播放清單或單一影片，產出結構化 Markdown 摘要，可直接匯入 NotebookLM。

## 輸入

- YouTube URL（頻道、播放清單或單一影片）

## 產出

| 檔案 | 說明 |
|------|------|
| `manifest.json` | 完整 metadata（影片清單、batch 配置） |
| `import-plan.md` | NotebookLM 匯入計畫 |
| `overview/channel-overview.md` | 頻道/清單總覽 |
| `batches/batch-XXX/batch-summary.md` | 每批摘要 |
| `batches/batch-XXX/videos/*.md` | 每部影片的摘要 + 逐字稿 |

## 產出存放位置

`50_Research/` 或 `30_Knowledge/01_AI_Tech/`（依主題歸類）

## 用法

```bash
# 基本用法
cd "/Users/Modema11434/Documents/New project"
.venv/bin/python yt_notebook_pipeline.py "https://www.youtube.com/playlist?list=PLxxxxxxx"

# 指定輸出目錄
.venv/bin/python yt_notebook_pipeline.py URL --output-dir /path/to/output

# 限制影片數量
.venv/bin/python yt_notebook_pipeline.py URL --max-videos 10

# 只抓最近 3 個月
.venv/bin/python yt_notebook_pipeline.py URL --months-back 3

# 包含完整逐字稿
.venv/bin/python yt_notebook_pipeline.py URL --include-transcript

# 指定字幕語言偏好
.venv/bin/python yt_notebook_pipeline.py URL --languages "zh-Hant,zh-TW,en"

# 去重（跳過已處理的影片）
.venv/bin/python yt_notebook_pipeline.py URL --dedupe-manifest /path/to/prev/manifest.json
```

## 參數

| 參數 | 預設 | 說明 |
|------|------|------|
| `url` | （必填） | YouTube URL |
| `--output-dir` | `output` | 輸出目錄 |
| `--batch-size` | 44 | 每個 NotebookLM notebook 的影片數 |
| `--max-videos` | 無限 | 最多處理幾部影片 |
| `--languages` | `zh-Hant,zh-TW,zh-Hans,zh,en` | 字幕語言偏好 |
| `--summary-sentences` | 5 | 每部影片的摘要句數 |
| `--include-transcript` | false | 是否包含完整逐字稿 |
| `--dedupe-manifest` | 無 | 前次 manifest.json 路徑（去重） |
| `--months-back` | 無 | 只抓最近 N 個月 |
| `--date-after` | 無 | 只抓此日期之後（YYYY-MM-DD） |

## 搭配 NotebookLM 匯入

```bash
# 匯入到 NotebookLM
node scripts/notebooklm-import-all.js --manifest /path/to/manifest.json --include-overview --headless
```

## 腳本位置

```
/Users/Modema11434/Documents/New project/
├── yt_notebook_pipeline.py          ← 主腳本
├── scripts/
│   ├── notebooklm-import-all.js     ← 批量匯入 NotebookLM
│   ├── notebooklm-import.js         ← 單一匯入
│   ├── notebooklm-auth.js           ← NotebookLM 認證
│   ├── notebooklm-cleanup.js        ← 清理
│   └── run-playlist-to-notebooklm.js ← 播放清單一鍵匯入
├── requirements.txt                 ← Python 依賴（yt-dlp, youtube-transcript-api）
└── package.json                     ← Node 依賴（playwright-core）
```
