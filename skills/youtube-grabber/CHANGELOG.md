# Changelog

## v1.0.0 — 2026-03-23

### 新增
- 初始版本，從 GPT Codex 產出包裝為 Life-OS Skill
- 支援 YouTube 頻道、播放清單、單一影片
- 產出 NotebookLM-ready Markdown 摘要包（manifest + batch + 逐字稿）

### 為什麼這樣做
- 需要把 YouTube 知識系統化進 NotebookLM，手動一部部太慢
- yt-dlp + youtube-transcript-api 是最穩定的字幕抓取方案
- batch size 44 = NotebookLM 單一 notebook 上限

### 已知問題 / 待觀察
- 無字幕影片（自動產生字幕除外）會失敗，需搭配 openai-whisper
- 中文字幕優先序：zh-Hant → zh-TW → zh-Hans → zh → en，部分頻道無中文字幕
- NotebookLM 匯入腳本依賴 playwright，需確認 browser 已安裝

---

## 待迭代方向

- [ ] 整合 openai-whisper 作為無字幕 fallback
- [ ] 支援多語言摘要輸出（自動偵測頻道語言）
- [ ] 去重邏輯優化（目前靠 --dedupe-manifest，考慮用 SQLite）

---
> 格式：版本 + 日期 → 改了什麼 → 為什麼 → 已知問題
> 目的：防止迭代後不知道前一版改過什麼又改回去
