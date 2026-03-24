---
name: Decisions Log — March 2026
description: 重要決策、技術選擇、架構決定、lessons learned
type: project
---

# 決策日誌 — 2026年3月

## 2026-03-23 — 派工系統確立

**決策**：建立「三大金剛」自動派工系統（Gemini CLI / Codex CLI / Claude Code）

**原因**：
- Haiku 模型效率已夠，複雜工作可委託
- Token 成本優化（60-90% 節省目標）
- 每個工具有清晰的適用場景

**技術選擇**：
- **Gemini CLI** → one-shot 內容工作（摘要、改寫、查詢）
- **Codex CLI** → 工程分析、單檔修改
- **Claude Code（我）** → 複雜重構、跨檔工作、需反饋的任務

**實施**：
- 已創建 `.claude/ROUTING.md` 派工決策樹
- 已測試三個工具都能正常調用
- 派工邏輯已驗證有效

**下次應用**：
- 遇到摘要/查詢 → 自動 Gemini（不用問）
- 遇到代碼分析 → Codex
- 其他情況根據 ROUTING.md 判斷

---

## 2026-03-23 — 記憶與 Session 壓縮

**決策**：記憶必須與龍蝦（OpenClaw）完全分離，session 壓縮時自動保存

**原因**：
- 龍蝦有自己的記憶系統，會相互干擾
- Session 會被自動壓縮，需要在壓縮前主動保存重要決策
- Life-OS 內必須記住用戶風格、決策、learned patterns

**原則**（「替換襪子」比喻）：
- 短期記憶：session 內的對話上下文
- 中期記憶：壓縮時主動保存到 `.claude/memory/` 磁碟
- 長期記憶：重要決策永久存儲

**實施**：
- 建立 `Life-OS/.claude/memory/` 獨立目錄（與龍蝦分離）
- 創建 user_profile.md、user_style.md、decisions、patterns 等
- 設計自動保存/加載機制
- **邊界清晰**：Life-OS 事務不越界到 ~/.claude/ 全局

**下次應用**：
- Session 開始時自動加載 memory/
- 遇到重要決策立刻寫入 decisions_YYYY-MM.md
- Session 結束前檢查 memory/ 是否已更新

---

## 2026-03-23 — Frame TV 影像模式澄清

**決策**：確認 Frame TV 海報生成用的是 Contain 模式，如需 Cover 改 min→max

**發現**：
- 檔案是 `art-composer.py`（不是 compose-poster.py）
- 目前用的是 **Contain 模式**（保留黑邊）
- 如需改成 Cover 模式（填滿），只要改第 24 行 `min()` → `max()`

**決策**：
- 保持 Contain 模式（符合直式肖像畫)
- 需要時用 Codex 完成修改

**實施**：
- 已用 Codex 驗證邏輯
- 修改方案清楚了

---

## 2026-03-23 — AI 工具堆棧確認

**決策**：以 Claude Pro + Gemini + ChatGPT 為主軸，三大金剛為執行層

**工具角色**：
| 工具 | 角色 | 成本 |
|------|------|------|
| Claude Code | 認知夥伴 + 主決策 | 中等 |
| Gemini CLI | 快速查詢 + 內容工作 | 低 |
| Codex CLI | 工程分析 | 低 |
| 龍蝦 LINE@ | 客服自動化 | 免費 |
| Obsidian | 知識庫 | 免費 |

**決策**：不追新工具，聚焦「停止開發，開始使用」

---

## 2026-03-22 — Git Repository 初始化

**決策**：初始化 Life-OS 為 git repository，以支援 Codex CLI

**原因**：
- Codex 要求在 git repository 內執行
- 生命 OS 需要版本控制

**實施**：
- `git init` in /Users/Modema11434/Documents/Life-OS/
- 已成功測試 Codex 派工

---

## 2026-03-23 — Vault 重構完成 Phase 1

**決策**：完成 Obsidian Vault 的層級重構（2 層結構）

**進度**：
- ✅ 新資料夾架構完整建立
  - 00_Inbox/（人類↔AI 討論區，分為 📥_Inbox / 🤖_AI_Tasks / 📌_Quick_Refs）
  - 10_Projects/（統一專案池，包括 11_System_Projects 的 3 個專案）
  - 20_Areas/（領域根節點）
  - 30_Knowledge/（結構化知識庫，新增 Tools.md）
  - 60_Deliverables/（私人工作區）
  - 90_System/（系統層，拆分為 01/02/03/04）

- ✅ 資料遷移 Phase 1-2 完成
  - 11_System_Projects → 10_Projects/ 複製完成
  - 92_Projects → 10_Projects/🦞_Lobster_Dashboard/ 複製完成（清理 .bak 備份檔）
  - .Trash/ 系統建立

- ✅ Deliverables 定義清楚
  - 90_System/inbox/Deliverables/（公開 Cloudflare URL，對外分享）
  - 60_Deliverables/（私人工作區，內部整理）
  - 在 Tools.md 中詳細定義

- ✅ 93_Deliverables 分析完成
  - assets（83 files, 96M）vs island-assets（78 files, 93M）
  - 檔名不同，各自不同用途
  - 其中一組是 LINE Rich Menu 現在在用，不能亂動
  - 決定先保留，之後慢慢清理舊圖

**待做**：
- [ ] 93_Deliverables → 遷移到 90_System/inbox/Deliverables/
- [ ] 舊資料夾（11_System_Projects、92_Projects）→ 移到 .Trash
- [ ] 93_Deliverables 的垃圾清理（之後確認後再刪）

**下 Session 切入點**：Vault 重構 Phase 2 — 93_Deliverables 遷移

---

## 待決策事項

- [ ] 「倒腦」系統完整實施（語音→任務拆解）
- [ ] 自動保存/加載 memory/ 的時機和機制
- [ ] Keep notes 的分類系統正式化
- [ ] Obsidian Vault 與 Keep 的同步策略
- [ ] 93_Deliverables 清理（之後逐步）
