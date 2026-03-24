# 自主派工 & 記憶持久化系統

> Claude Code 自主學習、自動派工、保存重要記憶的完整方案

---

## 系統設計

```
用戶輸入
    ↓
[Claude Code 分析] ← 加載 memory/
    ↓
決定派工或直接做
    ├─ Gemini CLI：摘要/改寫/一次性
    ├─ Codex CLI：工程分析/小修改
    ├─ 龍蝦技能：客服/Keep/Calendar
    └─ 我自己：複雜工程/協調
    ↓
執行 & 整合結果
    ↓
更新 memory/ ← 保存決策、學習到的模式
    ↓
回報給用戶
```

---

## 記憶持久化規則

### 記憶層次

| 層次 | 位置 | 生命週期 | 內容 |
|------|------|---------|------|
| **短期** | 對話上下文 | 本 session | 任務進度、中間結果 |
| **中期** | `memory/*.md` | 壓縮時保存 | 決策、風格、learned patterns |
| **長期** | `memory/` + Obsidian | 永久 | 重要決策、user profile |

### 自動保存清單

在 **session 壓縮時**，我應該主動保存：

1. **用戶風格** (`memory/user_style.md`)
   - 溝通偏好（直接、簡潔、不贅詞）
   - 決策模式（容易被「不想浪費」驅動，需踩煞車）
   - 工作節奏（無限開發循環 → 需提醒「停止開發」）

2. **決策日誌** (`memory/decisions_YYYY-MM.md`)
   - 技術決策（用什麼工具、為什麼）
   - 架構決策（怎麼組織代碼）
   - 優先級（什麼最重要）
   - 教訓（做過什麼失敗、成功的事）

3. **Learned Patterns** (`memory/patterns.md`)
   - 派工成功案例
   - 失敗案例 & 修正方向
   - 用戶偏好的工作流

---

## 自主派工規則

### Rule 1：分析任務類型

```python
if task_type == "one-shot_content":
    dispatch("Gemini CLI")
elif task_type == "engineering_analysis":
    dispatch("Codex CLI")
elif task_type == "life_assistant":
    dispatch("龍蝦技能")  # gkeep, calendar, etc.
elif task_type == "complex_engineering":
    do_it_myself("Claude Code")
```

### Rule 2：何時自動派工（不問用戶）

✅ **自動派工**（無需用戶明確要求）：
- 「幫我查一下 X」→ 自動 Gemini
- 「看一下這個代碼」→ 自動 Codex
- 「提醒我明天 9 點開會」→ 自動龍蝦 Calendar

❌ **不要自動派工**（要先問）：
- 改 Life-OS 的核心代碼
- 大型重構
- 需要反覆迭代的工作

### Rule 3：派工前檢查清單

派工前，我應該確認：
- [ ] 工作目錄正確（-C 參數）
- [ ] 任務描述清晰
- [ ] 有足夠的 context
- [ ] 知道怎麼整合結果

---

## 記憶檔案結構

```
~/.claude/projects/-Users-Modema11434-Documents-Life-OS/memory/
├── user_profile.md           # 用戶基本信息、偏好、ADHD context
├── user_style.md             # 溝通風格、決策模式、工作節奏
├── decisions_2026-03.md      # 3月的重要決策
├── decisions_2026-02.md      # 2月的重要決策
├── patterns.md               # 派工成功案例、教訓
├── tech_stack.md             # 技術棧選擇、工具清單
└── README.md                 # 這個系統的說明
```

### 每份檔案的內容格式

#### `user_profile.md`
```markdown
# User Profile

## 個人背景
- 神經多樣性（ADHD）
- 老闆，團隊不大
- 住高雄，有辦公室
- 兒子：豌豆

## 溝通風格
- 直接簡潔
- 不加稱號、不用贅詞
- 一次一個主題
- 語音輸入多
```

#### `decisions_YYYY-MM.md`
```markdown
# 決策日誌 - 2026年3月

## 2026-03-23 - 派工系統確定
**決策**：三大金剛（Gemini/Codex/Claude Code）自動路由
**原因**：提高效率、降低 token 消耗
**教訓**：一次性內容用 Gemini，不要用 Claude Code
**下次如何應用**：遇到摘要/查詢，自動 Gemini

## 2026-03-23 - Memory 分離
**決策**：Memory 必須與龍蝦分開
**原因**：防止被龍蝦的記憶影響
**實施**：`~/.claude/projects/.../memory/` 獨立存儲
```

#### `patterns.md`
```markdown
# Learned Patterns

## ✅ 成功案例
1. **Gemini + 摘要** - YouTube 視頻 800 字摘要，30 秒內完成
2. **Codex + 分析** - 單檔代碼分析，準確度高

## ❌ 失敗案例
1. **Frame TV 模式混亂** - Cover/Contain 概念搞反
   - 修正：Codex 分析，確認目前是 Contain，改 min→max 才是 Cover

## 📚 通用教訓
- 派工時要明確說工作目錄
- 簡單的事不要問 Claude Code，浪費 token
- 重要決策要立刻寫下來，不然 session 壓縮會丟
```

---

## 實施步驟

### Phase 1：基礎記憶（現在）
- [ ] 創建 `memory/user_profile.md`
- [ ] 創建 `memory/user_style.md`
- [ ] 創建 `memory/decisions_2026-03.md`
- [ ] 更新 CLAUDE.md 加入派工規則

### Phase 2：自動派工（下週）
- [ ] 實現派工決策邏輯（在 session 內自動判斷）
- [ ] 測試派工成功率
- [ ] 修正失敗案例

### Phase 3：自動持久化（之後）
- [ ] 在 session 結束時自動更新 memory/
- [ ] 實現 session 開始時自動加載 memory/
- [ ] 建立 memory 版本控制（git）

---

## 使用范例

### 範例 1：用戶提出新任務

```
用戶（Telegram）：「Youtube 那支影片把它整理成筆記放 Keep」

我的流程：
1. 識別任務：摘要 + 存儲
2. 派工決策：Gemini（摘要） + 龍蝦 gkeep（存儲）
3. 執行：
   - gemini "summarize youtube video, 800 words"
   - gkeep --add "..." --label "imported"
4. 更新 memory/patterns.md：「又一次 Gemini+龍蝦 組合成功」
5. 回報：「筆記已存到 Keep，標籤 imported」
```

### 範例 2：自動記憶重要決策

```
用戶：「我決定以後不用 ChatGPT，全轉 Claude」

我的流程：
1. 識別：重要決策
2. 保存到 memory/decisions_2026-03.md
3. 更新 memory/user_profile.md → AI 工具選擇
4. 下次 session 自動加載這個決策
5. 之後遇到「要用什麼 AI？」自動回答「Claude」
```

---

## 成功指標

- [ ] Session 壓縮前，自動保存 memory/
- [ ] 新 session 開始，自動加載 memory/
- [ ] 派工成功率 > 95%
- [ ] 用戶不需要重複說相同的決策
- [ ] 能自主判斷何時派工、何時自己做
- [ ] 整合結果準確、完整

---

## 版本

- **v0.1** - 2026-03-23 初版，架構設計
- **v0.2** - Phase 1 完成，基礎記憶建立
- **v0.3** - Phase 2 完成，自動派工
- **v1.0** - Phase 3 完成，完整自動化
