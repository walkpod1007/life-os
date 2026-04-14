# Claude Soul 內部文件重構 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重構 soul.md / capabilities.md / session-end skill，從結構上解決 MEMORY.md handoff 累積和技能盲點兩個問題。

**Architecture:** Gemini CLI 搜參考配置取結構模式 → Codex 審現有文件找矛盾和落差 → Opus 按審核結果執行六個文件重寫/修改 → 清理 MEMORY.md 殭屍索引 → 更新 Gist。

**Tech Stack:** Markdown，gemini CLI，codex CLI，bash 驗證，gh CLI（Gist 更新）

---

## 檔案清單

| 操作 | 路徑 | 說明 |
|------|------|------|
| 修改 | `~/Documents/life-os/soul.md` | 瘦身至 ≤60 行，移除踩坑規則 |
| 新建 | `~/Documents/life-os/soul-behaviors.md` | 踩坑規則分類版，加觸發標籤 |
| 修改 | `~/Documents/life-os/.claude/capabilities.md` | 重寫為三欄格式能力地圖 |
| 修改 | `~/.claude/CLAUDE.md` | session 開場加第 3 條（讀 capabilities.md） |
| 修改 | `~/Documents/life-os/skills/session-end/SKILL.md` | 移除第 3 步的 handoff 寫入指令 |
| 修改 | `~/.claude/projects/-Users-applyao-Documents-life-os/memory/MEMORY.md` | 清除所有 handoff 型殭屍索引 |

---

## Task 1：Gemini CLI 搜尋參考配置

**Files:**
- 讀取：無（網路搜尋）
- 輸出：觀察筆記，供 Task 3-4 參考

- [ ] **Step 1：確認 gemini CLI 可用**

```bash
gemini --version
```

Expected: 版本號輸出（已確認在 `/opt/homebrew/bin/gemini`）

- [ ] **Step 2：搜尋 GitHub 公開 CLAUDE.md 結構範例**

```bash
gemini -p "Search GitHub for real-world CLAUDE.md configuration files used by Claude Code power users. I want to understand: 1) how they separate identity/values from behavior rules, 2) what they keep in always-loaded context vs on-demand, 3) how they handle skill/capability discovery at session start. Show me 3-5 concrete structural patterns with file names and key sections. Focus on repos with claude-code topic or heavy Claude Code usage."
```

記錄下關鍵結構模式（切層方式、常駐 vs on-demand 的邊界在哪）。

- [ ] **Step 3：搜尋 soul.md / identity doc 最佳實踐**

```bash
gemini -p "Search for best practices in AI persona/identity documents for Claude Code or similar AI coding assistants. Specifically looking for: how to write behavior rules that actually get followed (not just ignored), how to structure a 'capabilities manifest' so the AI knows what tools it has at session start, any known patterns from YC founders or notable developers using Claude for personal productivity. Show concrete examples."
```

記錄：有沒有「能力地圖」的具體做法，別人用什麼格式讓 AI 知道自己的技能。

- [ ] **Step 4：commit 觀察筆記（選做）**

如果搜尋結果有值得保存的結構洞察，存到：
```
~/Documents/life-os/docs/superpowers/specs/2026-04-14-external-config-patterns.md
```

---

## Task 2：Codex 審核現有文件

**Files:**
- 讀取：`soul.md`，`skill-routes.md`，`skills/` 目錄，`memory/MEMORY.md`

- [ ] **Step 1：確認 codex CLI 可用**

```bash
codex --version
```

Expected: 版本號輸出（已確認在 `/opt/homebrew/bin/codex`）

- [ ] **Step 2：掃 soul.md 踩坑規則矛盾**

```bash
codex -q "Read this file and find any contradictory or ambiguous rules in the '阿普踩坑' section. Specifically look for rules that could conflict with each other (e.g., 'do X immediately' vs 'always ask before doing X'). List each conflict with the line numbers and explain the ambiguity." ~/Documents/life-os/soul.md
```

記錄矛盾清單，在 Task 4 寫 soul-behaviors.md 時解決。

- [ ] **Step 3：比對 skill-routes.md vs skills/ 目錄**

```bash
# 先列出所有實際安裝的 skills
ls ~/Documents/life-os/skills/

# 再列出 skill-routes.md 中引用的 skill 名稱
grep -oE '`[a-z][a-z0-9-]+`' ~/Documents/life-os/skill-routes.md | sort -u
```

然後：
```bash
codex -q "Compare these two lists and identify: 1) skills that exist in skills/ directory but have no route in skill-routes.md, 2) skill names referenced in skill-routes.md that don't exist as directories in skills/. Format as two clear lists." <(ls ~/Documents/life-os/skills/) <(grep -oE '`[a-z][a-z0-9-]+`' ~/Documents/life-os/skill-routes.md | tr -d '`' | sort -u)
```

記錄落差，在 Task 5 的 capabilities.md 只包含真實存在的技能。

- [ ] **Step 4：標出 MEMORY.md 殭屍條目**

```bash
grep -n "handoff\|交接" ~/.claude/projects/-Users-applyao-Documents-life-os/memory/MEMORY.md
```

記錄行號清單，Task 8 時一次清除。

---

## Task 3：修 session-end SKILL.md（根治 MEMORY handoff 問題）

**Files:**
- 修改：`~/Documents/life-os/skills/session-end/SKILL.md`

這是最高優先，先做。Root cause 在這：第 3 步明確叫 Claude 把 handoff 寫進 MEMORY.md。

- [ ] **Step 1：讀取現有 session-end SKILL.md**

```bash
cat ~/Documents/life-os/skills/session-end/SKILL.md
```

確認第 3 步的位置（應在第 20-21 行附近）。

- [ ] **Step 2：修改第 3 步內容**

將：
```
3. 寫 MEMORY.md 交接卡
   建立 memory/project_YYYY_MM_DD_handoff.md，append 到 MEMORY.md index
```

改為：
```
3. 寫 handoff.md（覆寫式交接卡）
   覆寫 ~/Documents/Life-OS/handoff.md，格式四段：SUMMARY / CURRENT / NEXT / LESSON
   禁止寫入 memory/ 目錄。如有值得長期保存的洞察（feedback/project/reference 型），
   另建對應型別的 memory 卡片，但這是選做，不是 session-end 必做流程。
```

同時修改 description frontmatter，移除「寫 MEMORY.md 交接卡」：
```yaml
description: Session 結束收尾流程：補尾段摘要 → 更新向量索引 → 寫 handoff.md → 判斷里程碑 → 自重啟。使用時機：要換 session、結束工作、/session-end、寫日檔。
```

同時修改輸出格式，把 `🧠 MEMORY.md 交接卡更新` 改為 `📋 handoff.md 覆寫完成`。

- [ ] **Step 3：驗證修改**

```bash
grep -n "MEMORY\|memory\|交接卡\|handoff" ~/Documents/life-os/skills/session-end/SKILL.md
```

Expected：不應出現「建立 memory/project」或「append 到 MEMORY.md」。

- [ ] **Step 4：commit**

```bash
cd ~/Documents/life-os
git add skills/session-end/SKILL.md
git commit -m "fix: session-end 移除 MEMORY.md handoff 寫入指令（根治殭屍累積問題）"
```

---

## Task 4：修 CLAUDE.md — 加 session 開場第 3 條

**Files:**
- 修改：`~/.claude/CLAUDE.md`

- [ ] **Step 1：讀取 session 開場規則段落**

```bash
grep -n -A 5 "Session 開始規則" ~/.claude/CLAUDE.md
```

確認目前只有 2 條規則（讀 handoff.md + MEMORY.md 不改動）。

- [ ] **Step 2：加入第 3 條**

在「2. MEMORY.md 只做記憶卡索引，不清空、不改動」之後加：
```
3. 讀取 `~/Documents/Life-OS/.claude/capabilities.md`，建立當前可用技能清單，session 期間有使用者需求時主動比對這份清單再回應。
```

- [ ] **Step 3：驗證**

```bash
grep -A 10 "Session 開始規則" ~/.claude/CLAUDE.md
```

Expected：出現 3 條規則，第 3 條提到 capabilities.md。

- [ ] **Step 4：commit（此檔案不在 life-os git 管，直接跳過或用 ~/.claude 的 git）**

```bash
cd ~/.claude && git add CLAUDE.md && git commit -m "feat: session 開場加第 3 條，讀 capabilities.md 建立技能地圖" 2>/dev/null || echo "~/.claude not a git repo, change saved directly"
```

---

## Task 5：重寫 soul.md（瘦身至 ≤60 行）

**Files:**
- 修改：`~/Documents/life-os/soul.md`（備份見 git history）

- [ ] **Step 1：確認備份存在**

```bash
cd ~/Documents/life-os && git log --oneline soul.md | head -3
```

Expected：有 commit 歷史，任何時間可還原。

- [ ] **Step 2：用 Opus 重寫（Agent 派工）**

以下內容用 **Opus** 執行（`model: opus`）：

讀取現有 `soul.md`，保留以下內容，其餘刪除：

**保留：**
- `soul_parameters` YAML 完整區塊（thinking_style / intellectual_anchors / values / relationship_to_user / blind_spots_to_watch / error_handling / cross_query_style）
- AI 使用原則（精簡為 5-7 條，每條一行）
- 已建立機制快覽（每行格式：`機制名：路徑 — 一句話說明`，最多 6 行）
- `⚠️ 踩坑` 警告（只留那一條「開始新任務前先問這機制是否存在」）

**移除：**
- 踩煞車規則段落（搬到 soul-behaviors.md）
- 不卸責條文（搬到 soul-behaviors.md）
- 「阿普踩坑 — 對話行為」整段（搬到 soul-behaviors.md）

**目標：≤60 行**

- [ ] **Step 3：驗證行數**

```bash
wc -l ~/Documents/life-os/soul.md
```

Expected：≤60 行。

- [ ] **Step 4：commit**

```bash
cd ~/Documents/life-os
git add soul.md
git commit -m "refactor: soul.md 瘦身至純靈魂層，移除行為規則至 soul-behaviors.md"
```

---

## Task 6：新建 soul-behaviors.md

**Files:**
- 新建：`~/Documents/life-os/soul-behaviors.md`

- [ ] **Step 1：用 Opus 撰寫（參考 Task 2 Codex 審核結果）**

從 soul.md 舊版本（`git show HEAD~1:soul.md` 或 Task 5 之前的備份）取出「阿普踩坑」所有規則，加上踩煞車規則 + 不卸責條文，重新組織成以下格式：

```markdown
---
name: soul-behaviors
description: Claude 對話行為規則，按類別索引。session 開場不需全讀，有行為疑問時查詢。
---

# soul-behaviors — 行為規則索引

> 這份文件是 soul.md 的延伸，存放具體行為規則。
> 查詢方式：按類別找，或 Cmd+F 搜觸發條件關鍵詞。

## 對話節奏
[觸發：回應節奏、問問題、填充詞]
- 先回答，再追問。一次最多問 1 個問題。
- 不用讚美填充回應（「觀察很深」「好問題」一律省略）。
- 整段語音聽完再判斷，不要每個片段急著對應。
...（其餘規則）

## 工具使用
[觸發：有 skill 時、搜尋時、動態網頁、capture 任務]
- 有現成技能/腳本就用現成的，不叫 agent 從頭重寫。
- 用戶說「搜尋 XXX」直接搜，不問用途。
- 動態網頁用 Playwright 不用 WebFetch。
- Capture 子代理用 Haiku。
...

## 記憶與脈絡
[觸發：引用時間詞、Telegram 時間戳、記憶浮現]
- 引用過去事件前先算時距，禁止憑印象推測相對時間。
- Telegram ts 是 UTC，自動 +8。
- 記憶浮現必須改變行為，不是讀過就算。
...

## 系統操作
[觸發：重啟、修復腳本、刪除操作、rename]
- 重啟必清殘留進程：pgrep 全掃 → kill all → 重啟後再掃一次確認。
- 修復後立刻手動跑一次驗證。
- 刪除前告知數量/範圍，等確認。
- 多檔案改名先列清單再改。
...

## 頻道行為
[觸發：Telegram、LINE、webhook、supervisor 腳本]
- Telegram 永遠走 lobster webhook，不掛官方 plugin。
- supervisor 腳本禁止 hardcode --channels plugin 參數。
- 搬家時清除所有自動重啟機制（crontab、LaunchAgents、keepalive）。
...

## 邊界保護
[觸發：授權邊界、作息、承諾、責任歸屬]
- 不卸責：技術問題自己解，不把工作丟回給使用者。
- 不跨邊界關心作息：不叫用戶休息/睡覺。
- 禁止過度承諾：不說「下次不會」「保證不再犯」。
- 不要跟著用戶的自責走，先確認事實再行動。
...
```

- [ ] **Step 2：在 CLAUDE.md 加載入說明（選做）**

如果需要讓所有 session 都能查到 soul-behaviors.md，在 CLAUDE.md 身份定義段落加一行：
```
- **行為規則**：具體對話行為規則 → 詳見 @soul-behaviors.md（有疑問時查，不需全讀）
```

- [ ] **Step 3：驗證分類完整**

```bash
# 確認原 soul.md 的踩坑條數 vs 新 soul-behaviors.md 的條數
git show HEAD~2:soul.md | grep -c "^-"
grep -c "^-" ~/Documents/life-os/soul-behaviors.md
```

兩個數字應接近（soul-behaviors 可能略多，因為有新增觸發標籤）。

- [ ] **Step 4：commit**

```bash
cd ~/Documents/life-os
git add soul-behaviors.md CLAUDE.md
git commit -m "feat: 新建 soul-behaviors.md — 踩坑規則分類索引"
```

---

## Task 7：重寫 capabilities.md

**Files:**
- 修改：`~/Documents/life-os/.claude/capabilities.md`

- [ ] **Step 1：讀取現有 capabilities.md**

```bash
cat ~/Documents/life-os/.claude/capabilities.md
```

確認目前是表格格式（兩欄：技能名 + 說明），最後更新 2026-03-24，可能有過時項目。

- [ ] **Step 2：取得當前真實安裝的技能清單**

```bash
ls ~/Documents/life-os/skills/ | sort
```

- [ ] **Step 3：用 Opus 重寫（三欄格式）**

重寫規則：
- 格式：`技能名 | 觸發關鍵詞 | 一句話用途`
- 只列 `skills/` 目錄中真實存在的技能
- 觸發關鍵詞從 `skill-routes.md` 取（每個技能取最具代表性的 1-3 個關鍵詞）
- 按用途分組：內容捕捉 / 知識管理 / 商業內容 / 日常運作 / 智慧居家 / 瀏覽器自動化 / 系統工具
- 移除 2026-03-24 後已刪除或改名的技能
- 加上最後更新日期

範例格式：
```markdown
# capabilities.md — 當前可用技能地圖
> 最後更新：2026-04-14
> Session 開場自動讀取，無需手動查詢。

## 內容捕捉
| 技能 | 觸發詞 | 用途 |
|------|--------|------|
| capture | 存起來、記下來、capture + URL | 擷取 URL 內容存 Obsidian Vault |
| podcast-grabber | Podcast、Spotify、Apple Podcasts + URL | 抓 Podcast 字幕 + 摘要 |
| youtube-grabber | YouTube URL（單影片） | 抓字幕 + 摘要 |
| youtube-batch | YouTube 頻道/播放清單 URL | 批次摘要 → Obsidian + NotebookLM |
...
```

- [ ] **Step 4：驗證技能名稱都存在**

```bash
# 從 capabilities.md 取出技能名稱，確認每個都在 skills/ 目錄
grep "^| " ~/Documents/life-os/.claude/capabilities.md | awk -F'|' '{print $2}' | tr -d ' ' | while read skill; do
  [ -d ~/Documents/life-os/skills/$skill ] && echo "✓ $skill" || echo "✗ MISSING: $skill"
done
```

Expected：全部 ✓，無 ✗。

- [ ] **Step 5：commit**

```bash
cd ~/Documents/life-os
git add .claude/capabilities.md
git commit -m "refactor: capabilities.md 重寫為三欄能力地圖，與現有 skills/ 目錄同步"
```

---

## Task 8：清理 MEMORY.md 殭屍索引

**Files:**
- 修改：`~/.claude/projects/-Users-applyao-Documents-life-os/memory/MEMORY.md`

- [ ] **Step 1：列出所有 handoff 型條目**

```bash
grep -n "handoff\|交接" ~/.claude/projects/-Users-applyao-Documents-life-os/memory/MEMORY.md
```

記錄行號範圍。

- [ ] **Step 2：確認保留條目**

保留清單（確認這幾條還有參考價值）：
```
## Project
- 記憶架構全貌 → 保留
- qmd-search MCP → 保留
- skill-patch 閉環 → 保留
- Channel 恢復 → 保留
- 2026-04-07 下午交接 → 評估（已超過一週，可能過時）

## Feedback
- capture 完成後 push 摘要 → 保留

## Reference
- Telegram Gist 備份 → 保留
```

所有 `project_2026_04_07_handoff*`、`project_2026_04_08_handoff*` 的 Reference 條目：**全部刪除**（共約 15 條）。

- [ ] **Step 3：執行清理**

用 Edit 工具精確移除每一條殭屍索引行，保留有效條目。

最終 MEMORY.md 應只剩：
```markdown
## Project
- [記憶架構全貌](...) — ...
- [qmd-search MCP](...) — ...
- [skill-patch 閉環](...) — ...
- [Channel 恢復](...) — ...

## Feedback
- [capture 完成後 push 摘要](...) — ...

## Reference
- [Telegram Gist 備份](...) — ...
```

- [ ] **Step 4：驗證行數**

```bash
wc -l ~/.claude/projects/-Users-applyao-Documents-life-os/memory/MEMORY.md
```

Expected：≤ 25 行。

- [ ] **Step 5：確認無 handoff 殘留**

```bash
grep "handoff\|交接" ~/.claude/projects/-Users-applyao-Documents-life-os/memory/MEMORY.md
```

Expected：無輸出。

---

## Task 9：更新 Gist

**Files:**
- 外部：Gist `7a46e9e314098ecdadefce08eade6919`（AGENTS.md）

- [ ] **Step 1：確認 gh CLI 已登入**

```bash
gh auth status
```

- [ ] **Step 2：查看現有 AGENTS.md 內容**

```bash
gh gist view 7a46e9e314098ecdadefce08eade6919
```

- [ ] **Step 3：新增派工紀錄**

在 AGENTS.md 的派工紀錄表追加一筆：

```
| 2026-04-14 | Claude Soul 重構 | soul.md 瘦身 + soul-behaviors.md + capabilities.md 重寫 + session-end 根治 MEMORY handoff + MEMORY.md 清理 | ✅ Done |
```

```bash
gh gist edit 7a46e9e314098ecdadefce08eade6919
```

（或用 `--filename AGENTS.md` 參數直接更新）

- [ ] **Step 4：確認 Telegram Gist 無需連動**

```bash
gh gist view ff91ac0628de94f3d263639c0464c40a | head -10
```

確認 Telegram LOBSTER FORK server.ts 的備份與本次重構無關，無需更新。

---

## 執行順序建議

```
Task 3（修 session-end，根治問題）
→ Task 4（修 CLAUDE.md）
→ Task 8（清 MEMORY.md 殭屍）
→ Task 1（Gemini 搜參考，先做研究再動 soul）
→ Task 2（Codex 審核）
→ Task 5（重寫 soul.md）
→ Task 6（新建 soul-behaviors.md）
→ Task 7（重寫 capabilities.md）
→ Task 9（更新 Gist）
```

先把「繼續製造垃圾的機制」關掉（Task 3），再清掉已有的垃圾（Task 8），最後才重建新結構。
