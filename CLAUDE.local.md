# CLAUDE.local.md — Life OS 專案指令

> 最後更新：2026-04-12

## Session 入口對應表

四個會跟我對話的入口，tmux session 名字跟管道的對應（2026-04-12 從 life/plan 改名）：

| 你的世界 | tmux session | supervisor 腳本 | 看門狗 |
|---|---|---|---|
| termi（終端機） | claude-terminal | `claude-terminal.sh` | ✅ |
| LINE | claude-line | `claude-line.sh` | ✅ |
| 手機/Mac App（remote-control） | claude-remote | `claude-remote.sh`（auto `/remote-control`） | ✅ |
| Telegram | claude-telegram | `claude-telegram.sh`（載 telegram-lobster MCP） | ✅ |

四個全部都被 token-watchdog 罩著，150K token 會自動 session-end → 重啟。手動接入：`tmux attach -t <name>`。手動重啟單一條：`bash ~/Documents/Life-OS/scripts/claude-<name>.sh`。

歷史包袱：舊名 claude-life 對應 Telegram、claude-plan 對應 remote-control；老的 daily log / handoff / pitfall 卡會看到舊名字，知道是同一個東西就好。


@/Users/applyao/Documents/Life-OS/handoff.md

## 技能路由

| 觸發條件 | 技能 |
|---------|------|
| instagram.com/p/ 或 /reel/ URL | `capture` → platform-instagram |
| threads.com / x.com / twitter.com URL | `capture` → 對應平台 |
| youtube.com / youtu.be URL（單一影片） | `capture` → Agent-Reach 快速抓 |
| youtube.com 頻道 / 播放清單 URL | `youtube-grabber` pipeline → NotebookLM |
| reddit.com URL | `capture` → platform-reddit |
| 「存起來」「記下來」「capture」+ URL | `capture` |
| 「出貼文」「出爆款」「寫 IG」 | `cash-content` |
| 「設計產品」「怎麼定價」 | `cash-highconvert` |
| 「設計漏斗」「DM 怎麼賣」 | `cash-sales` |
| 「設計自動化」「Bio 怎麼寫」 | `cash-automated` |
| 「搜」「查一下」「幫我搜」「找一下」+ 平台/關鍵詞（非存檔意圖） | `agent-reach` |
| 「小紅書」「抖音」「微博」「B站」「V2EX」「LinkedIn」+ 搜尋/瀏覽 | `agent-reach` |
| 「Google Keep」「Keep 筆記」「記事本」 | `gkeep` |
| 「報錯」「error」「掛了」「Exception」「crash」「排錯」 | `runbook` |
| 「主題研究」「種子研究」「topic seed」「研究素材」 | `topic-seed-researcher` |
| youtube.com 頻道 / 播放清單 URL（批次摘要輸出 Obsidian） | `youtube-batch` |
| 「掃地機」「Roborock」「Q Revo」 | `roborock` |
| 「空淨機」「PM2.5」 | `xiaomi-home` |
| 「開燈」「Hue」 | `openhue` |
| 「換畫」「Frame 電視」 | `samsung-frame-art` |
| 「SmartThings」「電視」 | `samsung-smartthings` |
| 「放歌」「Sonos」「音響」 | `sonoscli` |
| 「行程」「Google 行事曆」 | `gcal-check` |
| 「郵件」「Gmail」 | `gmail-triage` |
| 「晨報」「morning brief」 | `morning-brief` |
| Podcast / Spotify / Apple Podcasts URL | `podcast-grabber` |
| 「生成圖片」「imagen」 | `imagen-gen` |
| 「問筆記」「NotebookLM」 | `notebooklm-query` |
| 「查 vault」「查筆記 (本地)」「向量搜尋」「qmd」 | `qmd` → `qmd query "<自然語言>"`（混合 lex+vec+rerank）或 `qmd search "<關鍵字>"`（純 BM25）；需要精準抓單篇用 `qmd get <file>` |
| 「重啟 LINE」 | `line-restart` |
| 「訂票」「買票」「高鐵」「查高鐵」 | `playwright-task` → recipes/thsr.md |
| 「蝦皮」「幫我買」 | `playwright-task` → recipes/shopee.md（即興探路） |
| 「UNIQLO」 | `playwright-task` → recipes/uniqlo.md（即興探路） |
| 「訂餐廳」「訂位」「幫我訂」+ 餐廳名稱 | `playwright-task` → 即興探路 |
| 「列出清單」「我的清單」「有哪些清單」 | `sonoscli` → `playlist-manager.sh list` |
| 「存成清單」「存下來叫」+ 名稱 | `sonoscli` → `playlist-manager.sh save` |
| 「放清單」+ 名稱 / 「播放清單」+ 名稱 | `sonoscli` → `playlist-manager.sh play` |
| 「建 web app」「設計前端」「出 UI」「做頁面」「出儀表板」 | `frontend` → 選 plugins/frontend/recipes/ 對應食譜 → Agent 產出 HTML → 放 60_Deliverables/ |
| 「跑到完成」「一直跑直到」「反覆執行直到」+ 任務描述 | `ralph-loop` via RemoteTrigger，帶 --completion-promise |

capture / cash-* / agent-reach 一律開 Agent 子代理執行，主 session 只回「收到，擷取中」。
playwright-task 一律走 RemoteTrigger 背景執行，主 session 只回「收到，瀏覽器任務開始跑」。
ralph-loop 一律走 RemoteTrigger 背景執行，主 session 只回「收到，開始跑，完成條件：<條件>」。
frontend 任務一律開 Agent 子代理執行，主 session 只回「收到，UI 開始產出」。
看到 URL 先查技能表，有對應技能就走技能，不要 WebFetch。

## 子代理紅線（核心層保護）

任何子代理（Agent tool 派出的 worker）**禁止寫入**以下核心檔案：

- `soul.md`
- `~/.claude/CLAUDE.md`
- `CLAUDE.local.md`
- `~/.claude/projects/*/memory/MEMORY.md`
- `STATE.md`
- `~/.claude/flag.md`

**允許寫入的工作層：**
- `daily/` 目錄
- `drafts/` 目錄
- `cold-storage/` 目錄
- Obsidian Vault 的 `90-system/inbox/` 和 `30-resources/` 目錄

違反紅線的任務，主 session 要攔截並重新派工，不得讓 worker 自行決定寫入核心層。

