# Changelog

## v1.0.0 — 2026-03-23

### 新增
- 初始版本，把摘要檔案匯入 NotebookLM 筆記本
- 支援單檔、批量、從 youtube-grabber manifest 匯入
- 搭配 notebooklm-query 形成完整「存入 → 查詢」流程

### 為什麼這樣做
- youtube-grabber 產出的 Markdown 需要自動化匯入，手動一筆筆太慢
- notebooklm-py 的 write 功能是唯一自動化方案

### 已知問題 / 待觀察
- NotebookLM 單一 notebook 上限約 50 個來源，超過需分批
- 匯入後需等 NotebookLM 處理（幾秒到幾分鐘）
- 重複匯入同一文件行為待確認（是否自動去重）

---

## 待迭代方向

- [ ] 批量匯入進度顯示
- [ ] 自動偵測目標筆記本（根據內容主題）
- [ ] 整合 youtube-grabber 一鍵「抓 + 存」流程

---
> 格式：版本 + 日期 → 改了什麼 → 為什麼 → 已知問題
> 目的：防止迭代後不知道前一版改過什麼又改回去
