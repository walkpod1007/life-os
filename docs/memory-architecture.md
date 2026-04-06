# 阿普記憶架構

> 最後更新：2026-04-06

## 記憶循環總覽

```
對話進行中
  │
  ├─ flag.md 六欄感知（每 turn 寫入）
  │    mood / focus / need / thread / stance / taste
  │
  ├─ realtime-summary.sh（每 10 分鐘 cron）
  │    ├─ JSONL transcript → Haiku 摘要 → daily/YYYY-MM-DD/HHMM-{slug}.md
  │    ├─ STATE.md 更新（人類近況 / 阿普觀察 / 阿普踩坑）
  │    ├─ step-card-extract.sh（背景）→ atom 卡片 → Vault 80_apu/atoms/
  │    └─ qmd update + embed（向量索引即時更新）
  │
  ├─ session-to-md.sh（由 realtime-summary 呼叫）
  │    └─ JSONL → 純文字 .md → Life-OS/sessions/（完整對話備份）
  │
  └─ token-watchdog.sh（每 60 秒）
       └─ 150k tokens → session-end → realtime-summary → 重啟

凌晨 pipeline
  ├─ 00:30  memory-reindex.sh — qmd 向量索引全量重建
  ├─ 02:00  step1-flag-fetch.sh
  ├─ 03:00  step2.2-dream.sh — 做夢引擎
  ├─ 04:30  water-sink.sh — flag.md → USER.md 沉澱
  ├─ 05:00  daily-retention.sh
  └─ 05:30  gen-infra.sh / gen-dashboard-data.sh
```

## 資料層

| 層 | 位置 | 保留期 | 用途 |
|---|---|---|---|
| flag.md | ~/.claude/flag.md | 即時（每天沉澱到 USER.md） | 當前感知狀態 |
| Haiku 摘要 | Life-OS/daily/YYYY-MM-DD/*.md | 永久 | 搜尋用，已提煉 |
| 完整對話 | Life-OS/sessions/*.md | 30 天 | 回溯細節 |
| atom 卡片 | Vault/80_apu/atoms/ | 永久 | 固化知識 |
| STATE.md | Life-OS/STATE.md | 滾動最新 20 條 | 即時近況 |
| USER.md | Life-OS/USER.md | 永久（分 recent/enduring） | 人類畫像 |
| handoff.md | Life-OS/handoff.md | 覆寫式（只保留最新） | session 交接 |

## 搜尋層

| 工具 | 底層 | 速度 | 適用場景 |
|---|---|---|---|
| vault_search | qmd BM25 | 秒回 | 關鍵字：工具名、錯誤訊息、人名 |
| vault_query | qmd 向量 + HyDE | 10-20 秒 | 語意：「上次那個 X 怎麼處理的」 |

MCP server: `plugins/qmd-search/server.ts`（.mcp.json 已註冊）

## qmd 索引範圍

| Collection | 路徑 | 檔案數 |
|---|---|---|
| lifeos | ~/Documents/Life-OS | ~390 .md |
| vault | Obsidian Vault | ~1050 .md |

索引大小：~2.2GB（含 embedding vectors）
Embedding model: embeddinggemma（本地 GGML）

## 注入機制

- **被動佩戴**：server.ts 開場注入 13 張 atom 卡片（向量召回 top-13）
- **主動查詢**：vault_search / vault_query MCP tool（本次新增）
- **感知寫入**：boost_keywords 每 turn 更新 flag.md

## 已知限制

1. qmd 向量沒有時間衰減——三個月前和昨天的權重相同
2. qmd search 回傳片段不含 frontmatter，日期靠路徑解析（server.ts 已處理）
3. 完整對話（JSONL）在 .claude 裡會被 Claude Code 自動清理，需靠 session-to-md.sh 及時轉存
4. realtime-summary 依賴 cron PATH 設定，PATH 不對就靜默失敗（2026-04-06 修過一次）

## Changelog

### 2026-04-06
- 修復 realtime-summary.sh cron PATH 問題（3/29 以來未成功執行）
- 建立 qmd-search MCP server（vault_search + vault_query）
- 搜尋結果加入日期前綴
- 建立 session-to-md.sh（JSONL → .md 完整對話備份）
- 建立 bootstrap-channels.sh（LINE + Telegram 一鍵恢復）
- 修復 Telegram plugin server.ts 語法錯誤（第 218 行多餘 }）
- Telegram 重新配對（sender 7908106895）
- 所有自建 plugin 納入 git 版本控制
