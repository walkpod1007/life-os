# Claude Soul 內部文件重構 — Design Spec

> 建立日期：2026-04-14
> 狀態：待實作

---

## 問題陳述

現有三個核心症狀：

1. **規則寫了等於沒寫**：`session-end` 反覆把 handoff 寫進 MEMORY.md，違反已明訂規則。根本原因是靠 Claude 自律，結構上沒有阻擋機制。
2. **技能盲點**：skills/ 目錄有 60+ 個技能，但 session 開場沒有能力地圖，需要使用者提醒才知道某個技能存在。
3. **文件層次混亂**：soul.md 同時是哲學宣言、機制清單、30+ 條行為規則的大雜燴，每條規則平等排列，session 讀了等於沒讀。

---

## 目標

- soul.md 瘦身到 60 行以內，只留「我是誰」的核心層
- 踩坑規則獨立成 soul-behaviors.md，按類別分組，可被 Codex 審核
- capabilities.md 成為 session 開場必讀的能力地圖
- MEMORY.md 的 handoff 累積問題靠結構（不靠規則）解決
- session-end 流程有明確的寫入白名單，不可繞過

---

## 文件新架構

### 靈魂層 — `soul.md`（重寫，目標 ≤60 行）

只保留：
- AI 使用原則（5 條核心，不擴充）
- soul_parameters YAML（thinking_style / values / relationship_to_user / blind_spots）
- 已建立機制快覽（5 行以內，每行一個機制名稱 + 路徑）

不放：踩坑規則、操作指引、任何「怎麼做」的內容。

### 行為層 — `soul-behaviors.md`（新建）

從 soul.md 搬出踩坑規則，按以下類別分組：

| 類別 | 說明 |
|------|------|
| 對話節奏 | 先回答再追問、不用讚美填充、整段聽完再判斷 |
| 工具使用 | 有現成技能就用現成、動態網頁用 Playwright、Capture 用 Haiku |
| 記憶與脈絡 | 引用時間詞前先計算、Telegram ts 是 UTC |
| 系統操作 | 重啟必清殘留進程、修復後立刻補跑驗證、刪除前確認 |
| 頻道行為 | Telegram 走 lobster webhook、不 hardcode channels plugin |
| 邊界保護 | 不卸責、不跨界關心作息、禁止過度承諾 |

每條規則新增 `觸發條件` 標籤，格式：`[觸發：XXX] 規則內容`，讓 Codex 可以做結構化衝突掃描。

### 能力地圖 — `capabilities.md`（重寫）

格式：每行一個技能，固定三欄：`技能名 | 觸發關鍵詞 | 一句話用途`。

Session 開場規則（CLAUDE.md 第 3 條）：讀 capabilities.md，建立當前能力快覽。

由 Codex 定期對比 skill-routes.md 和 skills/ 目錄，確保同步。

---

## 記憶衛生機制

### MEMORY.md 結構性防護

`session-end` skill 修改：

**允許寫入 memory/ 的條目類型（白名單）：**
- `user` — 使用者身份/偏好
- `feedback` — 行為修正指引
- `project` — 進行中的專案事實
- `reference` — 外部資源指標

**明確禁止：**
- handoff 型內容（這是 `handoff.md` 的職責）
- 每次 session 的對話摘要
- 進行中任務的狀態（這是 Task 工具的職責）

### MEMORY.md 殭屍清理

現有 15+ 筆 2026-04-07/08 逐小時 handoff 參考條目，本次一次清除。
保留原則：只留 project / feedback / reference 類型中有實質參考價值的條目。

---

## 執行工具分工

### Gemini CLI — 搜尋參考配置

搜尋方向：
1. GitHub 高星的公開 CLAUDE.md 真實範例（特別是 claude-code 標籤下的 repo）
2. Claude Code 社群的 soul.md / identity doc 結構最佳實踐
3. 知名技術人公開的 AI 工作流文件分層模式

目標：取結構模式，不抄內容。了解別人怎麼切層、什麼放常駐 context、什麼做 on-demand。

### Codex — 審核現有文件

四個審核任務：
1. 掃 soul.md 踩坑規則，找互相矛盾或邊界模糊的條目
2. 比對 skill-routes.md vs skills/ 目錄，列落差（有路由無 skill / 有 skill 無路由）
3. 標出 MEMORY.md 所有 handoff 型殭屍條目
4. 審 soul.md 新草稿，確認關鍵規則無遺漏

### Opus — 執行重構

按 Gemini 結構參考 + Codex 審核結果，依序執行：

- [ ] 重寫 soul.md（瘦身至 ≤60 行）
- [ ] 新建 soul-behaviors.md（踩坑規則分類 + 觸發標籤）
- [ ] 重寫 capabilities.md（能力地圖，三欄格式）
- [ ] 修 CLAUDE.md：session 開場規則加第 3 條（讀 capabilities.md）
- [ ] 修 session-end skill：加入 memory 寫入白名單檢查
- [ ] 清理 MEMORY.md：移除所有 handoff 型索引，只保留有效條目

---

## Gist 更新

- **AGENTS.md Gist**（`7a46e9e314098ecdadefce08eade6919`）：新增一筆派工紀錄，記錄本次重構任務狀態
- **Telegram LOBSTER FORK Gist**（`ff91ac0628de94f3d263639c0464c40a`）：確認是否有連動需要更新

---

## 成功標準

1. `soul.md` ≤ 60 行，無行為規則
2. `soul-behaviors.md` 存在，規則按類別分組，每條有觸發標籤
3. `capabilities.md` 每行三欄，與 skills/ 目錄同步
4. CLAUDE.md session 開場規則有第 3 條（讀 capabilities.md）
5. `session-end` skill 有明確 memory 寫入白名單，結構上不可繞過
6. MEMORY.md 無 handoff 型條目，總行數 ≤ 50 行
