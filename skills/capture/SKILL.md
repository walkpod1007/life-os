---
name: capture
description: 萬能 URL 捕捉手。偵測訊息中的 URL，自動判斷平台類型，擷取全文/摘要，存入 Obsidian 00_Inbox/，透過 Telegram 回覆 300 字摘要。支援：Threads、X/Twitter、Instagram、Facebook、Dcard、PTT、知乎、Reddit、YouTube、Podcast、一般文章/PDF。使用時機：任何 URL 出現在對話中且用戶想保存、幫我存、記起來、存到筆記、這個存起來、capture。
---

# Capture — 萬能 URL 捕捉手

## Overview

URL 進來 → 判斷平台 → 擷取 → 存 Vault → Telegram 回覆摘要。

讀 GOTCHAS.md 再動手，很多坑已經踩過了。

## Step 1：平台識別

| URL Pattern | 平台 | 策略文件 |
|-------------|------|---------|
| threads.com, threads.net | Threads | refs/platform-threads.md |
| twitter.com, x.com | X/Twitter | refs/platform-x.md |
| instagram.com/p/, /reel/ | Instagram | refs/platform-instagram.md |
| facebook.com, fb.com | Facebook | refs/platform-facebook.md |
| dcard.tw | Dcard | refs/platform-dcard.md |
| ptt.cc | PTT | refs/platform-ptt.md |
| zhihu.com | 知乎 | refs/platform-zhihu.md |
| reddit.com, redd.it | Reddit | refs/platform-reddit.md |
| youtube.com, youtu.be | YouTube | → youtube-grabber skill |
| .mp3, anchor, spotify podcast | Podcast | → podcast-grabber skill |
| 其他 | 通用文章/PDF | summarize CLI |

## Step 2：擷取

依平台策略文件執行。降級順序（通用）：
1. curl OG tags
2. web_fetch 全文
3. Browser Relay（最後手段，需 Chrome + 外掛）

## Step 3：AI 生成摘要 + Tags

- **標題**：正規化繁體中文，10-30 字，格式：核心主題-補充描述
- **Telegram 摘要**：約 500 字，分 3 段落，手機好讀（每段 30-60 字）
- **深度摘要**：800-1200 字，涵蓋主要論點、背景脈絡、關鍵細節、留言精華
- **Tags**：3 個語意 tag（主題 + 內容性質 + 具體關鍵字），繁體中文
- **留言精華**：社群平台挑 3-5 則最有代表性的（存入深度摘要）

## Step 4：存 Obsidian 📌_Quick_Refs/

```
VAULT="/Users/Modema11434/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault"
檔名：YYYY-MM-DD-正規化標題.md
路徑：$VAULT/00_Inbox/📌_Quick_Refs/YYYY-MM-DD-正規化標題.md
```

Frontmatter + 內文格式詳見 refs/obsidian-template.md。

**完成後驗證**：用 `ls` 確認檔案實際落地，不能只存在 session 記憶。

## Step 5：Telegram 回覆

- 正規化標題
- 500 字摘要（3 段落，每段 50-80 字）
- 結尾：「📥 已存 Vault」

## capture vs youtube-grabber 的區別

| | capture | youtube-grabber |
|--|---------|----------------|
| 觸發 | 朋友分享、隨意瀏覽、想立刻確認 | 訂閱頻道批量收割 |
| 單位 | 單篇即時 | 多篇累積 |
| 去哪 | Vault 00_Inbox/📌_Quick_Refs/ | NotebookLM 知識庫 |
| YT 單篇 | ✅ 走 capture（進 inbox） | 批量時才走這個 |

## 圖片處理原則

**預設不下載**，只在 frontmatter 記 `og_image` URL。

例外（下載到 Vault `00_Inbox/attachments/`）：
1. 資訊圖表（流程圖、對照表、數據視覺化）
2. 來源可能消失（限時動態、可能被刪的帖子）
3. 用戶自己的照片/截圖

## 原文保留原則

**一律原文照搬，不改寫不潤飾。**把抓到的原文、摘要、留言原封不動存入。
