---
title: "EVOLUTION"
created: 2026-03-23
tags: [system]
---

# Evolution
## Research Notes
- podcast_notebook_pipeline.py 支援 RSS、Spotify、Apple Podcasts URL
- podcast_sync.py 可增量同步，偵測新集數
- 需要 playwright 來匯入 NotebookLM（舊方式），現可改用 notebooklm-py

## Proposals (pending review)
- 整合 notebooklm-py 取代 Playwright 匯入
- 支援 cron 每日自動同步 feed
- 與 youtube-grabber 共用主題分類設定檔
