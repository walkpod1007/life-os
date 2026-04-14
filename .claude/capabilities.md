# capabilities.md — 當前可用技能地圖
> 最後更新：2026-04-14
> Session 開場自動讀取。收到使用者請求時主動比對此表，不需使用者提醒。

## 內容捕捉

| 技能 | 觸發詞 | 用途 |
|------|--------|------|
| agent-reach | 搜、查一下、幫我搜、找一下、小紅書/抖音/B站 + 搜尋 | 跨平台搜尋（非存檔意圖） |
| capture | 存起來、記下來、capture + URL | 擷取 URL 內容（IG/Threads/X/YouTube/Reddit）存 Obsidian Vault |
| link-capture | （capture 內部路由） | 社群連結截取，capture 子模組 |
| podcast-grabber | Podcast URL、Spotify、Apple Podcasts URL | 抓 Podcast 字幕 + 摘要存 Vault |
| youtube-grabber | youtube.com 頻道/播放清單 URL | 批次抓 YouTube 字幕 + 摘要，接 NotebookLM pipeline |
| youtube-batch | youtube 頻道批次摘要 → Obsidian | 批次 YouTube 摘要歸檔 Obsidian |
| youtube-summarizer | （capture 內部路由） | 單片 YouTube 摘要，capture 子模組 |

## 知識管理

| 技能 | 觸發詞 | 用途 |
|------|--------|------|
| notebooklm-query | 問筆記、NotebookLM | 查詢 NotebookLM 知識庫 |
| notebooklm-save | （notebooklm-query 後續動作） | 查詢結果存 Obsidian Vault |
| obsidian-capture | （capture 內部路由） | 想法/文字直接寫入 Obsidian Vault |
| topic-seed-researcher | 主題研究、種子研究、topic seed、研究素材 | 多源研究素材彙整 |
| gkeep | Google Keep、Keep 筆記、記事本 | 讀寫 Google Keep 筆記 |
| imagen-gen | 生成圖片、imagen | Gemini Imagen 文生圖 |
| nano-banana-2 | （imagen-gen 內部替代） | Gemini Flash 快速生圖 |

## 商業內容（CASH 框架）

| 技能 | 觸發詞 | 用途 |
|------|--------|------|
| cash-content | 出貼文、出爆款、寫 IG | CASH 框架社群貼文產出 |
| cash-highconvert | 設計產品、怎麼定價 | 高轉換產品設計與定價 |
| cash-sales | 設計漏斗、DM 怎麼賣 | 銷售漏斗與 DM 話術設計 |
| cash-automated | 設計自動化、Bio 怎麼寫 | 自動化流程與個人簡介設計 |

## 日常運作

| 技能 | 觸發詞 | 用途 |
|------|--------|------|
| gcal-check | 行程、Google 行事曆 | 查詢 Google Calendar 今日/未來行程 |
| gmail-triage | 郵件、Gmail | Gmail 分流與重要信件摘要 |
| morning-brief | 晨報、morning brief | 早安簡報：行程 + 天氣 + 待辦整合 |
| runbook | 報錯、error、掛了、Exception、crash、排錯 | 錯誤診斷與修復 runbook |
| daily-log | （cron / session-end 觸發） | 寫入今日日誌 |
| daily-review | （morning-brief 內部呼叫） | 每日晨間作戰計劃 |
| life-os-checklist | （morning-brief 內部呼叫） | 週期事務追蹤清單 |
| heartbeat-checkin | （cron 每 2 小時） | 定時心跳確認 → Telegram |
| week-push | （cron 週日） | 週報自動推播 → Telegram |
| insight | （week-push 內部呼叫） | 週回顧洞察生成 |
| social-monitor | （cron 排程） | Reddit/PTT 輿情監控 |
| sp500 | （cron 排程） | SP500 選股追蹤 |
| content-digest | （cron 排程） | 訂閱源摘要 → Telegram |

## 智慧居家

| 技能 | 觸發詞 | 用途 |
|------|--------|------|
| smart-home | （其他 smart-home 的 fallback） | 智慧居家統一入口路由 |
| roborock | 掃地機、Roborock、Q Revo | 掃地機器人啟動/排程控制 |
| xiaomi-home | 空淨機、PM2.5 | 小米空氣淨化器狀態與控制 |
| openhue | 開燈、Hue | Philips Hue 燈光場景控制 |
| samsung-frame-art | 換畫、Frame 電視 | 三星 Frame 電視藝術圖換畫 |
| samsung-smartthings | SmartThings、電視 | SmartThings 家電整合控制 |
| sonoscli | 放歌、Sonos、音響、列出清單、存成清單、放清單 | Sonos 音響播放與播放清單管理 |

## 瀏覽器自動化

| 技能 | 觸發詞 | 用途 |
|------|--------|------|
| *(playwright via /playwright-task)* | 訂票、買票、高鐵、蝦皮、UNIQLO、訂餐廳 | Playwright 瀏覽器自動化（走 RemoteTrigger） |

## 系統工具

| 技能 | 觸發詞 | 用途 |
|------|--------|------|
| loop-manager | 跑到完成、一直跑直到、反覆執行 | Loop 任務管理與自我分頁 |
| pipeline | （手動觸發） | 輸送帶多步驟任務推進 |
| triad-tools | （手動觸發） | Claude/GPT/Gemini 三模型分工路由 |
| vidclaw-task | （手動觸發） | VidClaw 影片任務執行 |
| yt-manage | （手動觸發） | 科技狗頻道管理 |
| skill-optimizer | （手動觸發） | 技能優化建議產出 |

## Channel 行為層（session 自動載入，不需使用者觸發）

| 技能 | 載入時機 | 用途 |
|------|----------|------|
| line-behavior | claude-line session | LINE 訊息行為規則 |
| line-dispatcher | claude-line session | LINE 訊息分派 |
| line-media | claude-line session | LINE 媒體處理規則 |
| line-output | claude-line session | LINE 回應格式規則 |
| telegram-behavior | claude-telegram session | Telegram 訊息行為規則 |
| telegram-dispatcher | claude-telegram session | Telegram 訊息分派 |
| telegram-handler | claude-telegram session | Telegram 訊息處理 |
| telegram-media | claude-telegram session | Telegram 媒體處理規則 |
| telegram-output | claude-telegram session | Telegram 回應格式規則 |
| group-silence-gating | channel sessions | 群組訊息沉默門控 |
| reply | 所有 session | 所有 agent 回話格式總閘 |
| session-end | session 收尾 | Session 收尾完整流程 |
| session-cleanup | 系統內部 | Session 清理 |
| session-reset | 系統內部 | Session 重置 |
| skill-vetting | 系統內部 | 新 skill 安全審查 |
| cloudflared-tunnel | 系統內部 | Tunnel 診斷修復 |
