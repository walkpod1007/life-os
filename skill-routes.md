# 技能路由表
> 更新：2026-04-13

## 路由規則

看到使用者訊息時，按此表比對觸發條件。命中就走對應技能，不要 WebFetch。

### 內容捕捉

| 觸發條件 | 技能 | 類型 | 派工方式 |
|---------|------|------|---------|
| instagram.com/p/ 或 /reel/ URL | `capture` → platform-instagram | skill | Agent 子代理 |
| threads.com / x.com / twitter.com URL | `capture` → 對應平台 | skill | Agent 子代理 |
| youtube.com / youtu.be URL（單一影片） | `capture` → Agent-Reach 快速抓 | skill | Agent 子代理 |
| reddit.com URL | `capture` → platform-reddit | skill | Agent 子代理 |
| Podcast / Spotify / Apple Podcasts URL | `podcast-grabber` | skill | Agent 子代理 |
| 「存起來」「記下來」「capture」+ URL | `capture` | skill | Agent 子代理 |
| 「搜」「查一下」「幫我搜」「找一下」+ 平台/關鍵詞（非存檔意圖） | `agent-reach` | skill | Agent 子代理 |
| 「小紅書」「抖音」「微博」「B站」「V2EX」「LinkedIn」+ 搜尋/瀏覽 | `agent-reach` | skill | Agent 子代理 |

### 知識管理

| 觸發條件 | 技能 | 類型 | 派工方式 |
|---------|------|------|---------|
| youtube.com 頻道 / 播放清單 URL | `youtube-grabber` pipeline → NotebookLM | skill | Agent 子代理 |
| youtube.com 頻道 / 播放清單（批次摘要 → Obsidian） | `youtube-batch` | skill | Agent 子代理 |
| 「問筆記」「NotebookLM」 | `notebooklm-query` | skill | 主 session |
| 「查 vault」「查筆記 (本地)」「向量搜尋」「qmd」 | `vault_query` / `vault_search` | mcp | 主 session |
| 「主題研究」「種子研究」「topic seed」「研究素材」 | `topic-seed-researcher` | skill | Agent 子代理 |
| 「Google Keep」「Keep 筆記」「記事本」 | `gkeep` | skill | 主 session |
| 「生成圖片」「imagen」 | `imagen-gen` | skill | 主 session |

### 商業內容（CASH 框架）

| 觸發條件 | 技能 | 類型 | 派工方式 |
|---------|------|------|---------|
| 「出貼文」「出爆款」「寫 IG」 | `cash-content` | skill | Agent 子代理 |
| 「設計產品」「怎麼定價」 | `cash-highconvert` | skill | Agent 子代理 |
| 「設計漏斗」「DM 怎麼賣」 | `cash-sales` | skill | Agent 子代理 |
| 「設計自動化」「Bio 怎麼寫」 | `cash-automated` | skill | Agent 子代理 |

### 日常運作

| 觸發條件 | 技能 | 類型 | 派工方式 |
|---------|------|------|---------|
| 「行程」「Google 行事曆」 | `gcal-check` | skill | 主 session |
| 「郵件」「Gmail」 | `gmail-triage` | skill | 主 session |
| 「晨報」「morning brief」 | `morning-brief` | skill | 主 session |
| 「報錯」「error」「掛了」「Exception」「crash」「排錯」 | `runbook` | skill | 主 session |

### 智慧居家

| 觸發條件 | 技能 | 類型 | 派工方式 |
|---------|------|------|---------|
| 「掃地機」「Roborock」「Q Revo」 | `roborock` | skill | 主 session |
| 「空淨機」「PM2.5」 | `xiaomi-home` | skill | 主 session |
| 「開燈」「Hue」 | `openhue` | skill | 主 session |
| 「換畫」「Frame 電視」 | `samsung-frame-art` | skill | 主 session |
| 「SmartThings」「電視」 | `samsung-smartthings` | skill | 主 session |
| 「放歌」「Sonos」「音響」 | `sonoscli` | skill | 主 session |
| 「列出清單」「我的清單」「有哪些清單」 | `sonoscli` → `playlist-manager.sh list` | skill | 主 session |
| 「存成清單」「存下來叫」+ 名稱 | `sonoscli` → `playlist-manager.sh save` | skill | 主 session |
| 「放清單」+ 名稱 / 「播放清單」+ 名稱 | `sonoscli` → `playlist-manager.sh play` | skill | 主 session |

### 瀏覽器自動化

| 觸發條件 | 技能 | 類型 | 派工方式 |
|---------|------|------|---------|
| 「訂票」「買票」「高鐵」「查高鐵」 | `/playwright-task` → recipes/thsr.md | command | RemoteTrigger |
| 「蝦皮」「幫我買」 | `/playwright-task` → 即興探路 | command | RemoteTrigger |
| 「UNIQLO」 | `/playwright-task` → recipes/uniqlo.md | command | RemoteTrigger |
| 「訂餐廳」「訂位」「幫我訂」+ 餐廳名稱 | `/playwright-task` → 即興探路 | command | RemoteTrigger |

### 前端 / UI 產出

| 觸發條件 | 技能 | 類型 | 派工方式 |
|---------|------|------|---------|
| 「建 web app」「設計前端」「出 UI」「做頁面」「出儀表板」 | `frontend` → plugins/frontend/recipes/ | plugin | Agent 子代理 |

### 系統工具

| 觸發條件 | 技能 | 類型 | 派工方式 |
|---------|------|------|---------|
| 「重啟 LINE」 | `scripts/claude-line.sh` | script | 主 session bash |
| 「跑到完成」「一直跑直到」「反覆執行直到」+ 任務描述 | `ralph-loop` | remote | RemoteTrigger |

## 派工規則

- **Agent 子代理**：主 session 只回「收到，[動作]中」，開 Agent tool 執行
- **RemoteTrigger**：主 session 只回「收到，背景任務開始跑」，走 RemoteTrigger
- **主 session**：直接在當前 session 執行
- **主 session bash**：直接跑 bash 腳本

## 不在路由表的技能（被動載入 / Channel 專用 / 系統內部）

這些技能不需要觸發條件，由特定 session 或 cron 自動使用：

| 技能 | 用途 | 載入時機 |
|------|------|---------|
| `telegram-dispatcher` | Telegram channel 唯一路由入口 | claude-telegram session 自動載入 |
| `line-dispatcher` | LINE channel 唯一路由入口 | claude-line session 自動載入 |
| `telegram-behavior` / `telegram-handler` / `telegram-output` / `telegram-media` | Telegram channel 處理 skill（由 dispatcher 呼叫） | claude-telegram session 自動載入 |
| `line-behavior` / `line-output` / `line-media` | LINE channel 處理 skill（由 dispatcher 呼叫） | claude-line session 自動載入 |
| `group-silence-gating` | 群組訊息沉默門控 | channel sessions 自動載入 |
| `reply` | 所有 agent 回話格式總閘 | 所有 session 自動載入 |
| `daily-log` | 手動/cron 觸發今日日誌 | cron / session-end |
| `daily-review` | 早晨作戰計劃 | morning-brief 內部呼叫 |
| `content-digest` | 訂閱源摘要 → Telegram | cron 排程 |
| `heartbeat-checkin` | 每 2 小時 Telegram 簽到 | cron 排程 |
| `week-push` | 週日自動週報 → Telegram | cron 排程 |
| `insight` | 週回顧洞察 | week-push 內部呼叫 |
| `life-os-checklist` | 週期事務追蹤 | morning-brief 內部呼叫 |
| `social-monitor` | Reddit/PTT 輿情 | cron 排程 |
| `obsidian-capture` | 想法/文字寫入 Vault | capture 內部路由 |
| `link-capture` | 社群截取 | capture 內部路由 |
| `notebooklm-save` | 查詢結果存 Vault | notebooklm-query 後續動作 |
| `youtube-summarizer` | 單片 YouTube 摘要 | capture 內部路由 |
| `yt-manage` | 科技狗頻道管理 | 手動觸發 |
| `smart-home` | 統一入口路由 | 其他 smart-home 技能的 fallback |
| `nano-banana-2` | Gemini Flash 快速生圖 | imagen-gen 內部替代 |
| `loop-manager` | Loop 任務管理 | /loop command 內部 |
| `pipeline` | 輸送帶任務推進 | 手動觸發 |
| `sp500` | SP500 選股追蹤 | cron 排程 |
| `triad-tools` | 多模型派工路由 | 手動觸發 |
| `vidclaw-task` | VidClaw 影片任務 | 手動觸發 |

## 已棄用

| 技能 | 棄用時間 | 原因 |
|------|---------|------|
| `gist-publisher` | 2026-03-21 | 改用 Vault + vault.life-os.work |
| `island-growth` | 2026-03-21 | 純背景系統，無人類觸發場景 |

## 系統內部（不對使用者暴露）

| 技能 | 用途 |
|------|------|
| `cloudflared-tunnel` | Tunnel 診斷修復 |
| `skill-optimizer` | Skill 優化建議 |
| `skill-vetting` | 新 skill 安全審查 |
| `session-end` | Session 收尾流程 |
| `session-cleanup` | Session 清理 |
| `session-reset` | Session 重置 |
| `runbook` | 已在路由表，但也被 cron 內部呼叫 |
