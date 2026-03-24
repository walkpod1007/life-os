# Changelog

## v1.0.0 — 2026-03-23

### 新增
- 初始版本，從 GPT Codex 產出包裝為 Life-OS Skill
- 支援 RSS feed 和直接 MP3 URL
- 透過 openai-whisper 轉錄音訊，產出摘要

### 為什麼這樣做
- Podcast 沒有字幕，需要 whisper 轉錄才能進 NotebookLM
- 跟 youtube-grabber 形成互補：YT 用字幕，Podcast 用語音轉錄

### 已知問題 / 待觀察
- whisper 轉錄速度慢，長集數（60min+）在 Mac mini 上約需 5-10 分鐘
- RSS feed 格式各家不同，部分 feed 需要特殊處理
- 中文 Podcast 轉錄準確率待驗證（whisper large-v3 較佳）

---

## 待迭代方向

- [ ] 加入 faster-whisper 作為加速選項
- [ ] RSS 批量抓取（整個 Podcast 頻道）
- [ ] 自動偵測語言並選擇對應 whisper model

---
> 格式：版本 + 日期 → 改了什麼 → 為什麼 → 已知問題
> 目的：防止迭代後不知道前一版改過什麼又改回去
