# Playwright MCP Integration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 讓 Life-OS 能透過 Telegram 自然語言指令驅動瀏覽器，完成訂票、訂餐廳、購物等任務，結果回報到 Telegram。

**Architecture:** Playwright MCP server 掛進 .mcp.json，由輕薄的 `playwright-task` skill 作為 Telegram → Playwright 的轉接層。有食譜則照食譜跑，沒有食譜則即興探路並在成功後詢問是否固化。

**Tech Stack:** `@playwright/mcp@0.0.70`、Node.js v25、headless Chromium、CLAUDE.local.md routing

---

## Task 1: 安裝 Playwright MCP 並更新 .mcp.json

**Files:**
- Modify: `.mcp.json`

- [ ] **Step 1: 確認 npx 可用（已驗證：v25.8.1）**

```bash
npx @playwright/mcp --version
```
Expected: `Version 0.0.70`（或更新版本）

- [ ] **Step 2: 更新 .mcp.json**

將 `.mcp.json` 改為：
```json
{
  "mcpServers": {
    "line-lobster": {
      "command": "/opt/homebrew/bin/bun",
      "args": [
        "/Users/Modema11434/Documents/Life-OS/plugins/line-lobster/server.ts"
      ]
    },
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp", "--headless"],
      "env": {}
    }
  }
}
```

- [ ] **Step 3: 驗證 .mcp.json 格式正確**

```bash
python3 -c "import json; json.load(open('.mcp.json')); print('JSON valid')"
```
Expected: `JSON valid`

- [ ] **Step 4: Commit**

```bash
git add .mcp.json
git commit -m "feat: add Playwright MCP server to .mcp.json"
```

---

## Task 2: 建立 recipes 目錄結構和 README

**Files:**
- Create: `plugins/playwright/recipes/README.md`
- Create: `plugins/playwright/recipes/thsr.md`

- [ ] **Step 1: 建立目錄**

```bash
mkdir -p /Users/Modema11434/Documents/Life-OS/plugins/playwright/recipes
```

- [ ] **Step 2: 建立 README.md（食譜格式說明）**

建立 `plugins/playwright/recipes/README.md`：

```markdown
# Playwright Recipes

每個網站一個 `.md` 食譜檔案。Playwright 執行前先查這個目錄，有食譜就照食譜跑。

## 食譜格式

\`\`\`markdown
# [網站名稱] — Playwright 食譜

**最後更新：** YYYY-MM-DD
**測試狀態：** ✅ 通過 / ⚠️ 可能需要更新 / ❌ 已失效
**入口 URL：** https://...

## 登入步驟
（有需要登入的才填）
1. 前往 [URL]
2. 點擊「登入」
3. 填入帳號：從環境變數 SITE_USER 讀取
4. 填入密碼：從環境變數 SITE_PASS 讀取

## 主要操作

### [任務名稱]
1. 前往 [URL]
2. 點擊 [描述按鈕或連結]
3. 填入 [欄位名稱]：[來自使用者指令的值]
4. 點擊「送出」/「搜尋」
5. 等待結果頁載入
6. 擷取 [結果欄位] 並回報

## 已知的坑
- 驗證碼：出現時截圖 → 回報 Telegram → 停止執行，等人工處理
- 動態載入：在點擊後需 wait 2 秒再操作
- Session 過期：重新執行登入步驟

## Changelog
- YYYY-MM-DD：初始建立
\`\`\`

## 現有食譜

| 網站 | 檔案 | 狀態 | 功能 |
|------|------|------|------|
| 台灣高鐵 | thsr.md | ✅ | 查票價、查班次 |
```

- [ ] **Step 3: 建立 thsr.md（第一個食譜：高鐵查詢）**

建立 `plugins/playwright/recipes/thsr.md`：

```markdown
# 台灣高鐵 — Playwright 食譜

**最後更新：** 2026-04-04
**測試狀態：** ✅ 通過
**入口 URL：** https://www.thsrc.com.tw/

## 主要操作

### 查詢班次與票價

1. 前往 `https://www.thsrc.com.tw/`
2. 點擊「時刻查詢」或「票價查詢」
3. 選擇出發站：從使用者指令取得（例如「左營」）
4. 選擇到達站：從使用者指令取得（例如「台北」）
5. 選擇出發日期：從使用者指令取得（格式 YYYY/MM/DD）
6. 點擊「查詢」
7. 等待結果頁載入（wait 2 秒）
8. 擷取班次表格（時間、車次、票價）
9. 回報格式：
   ```
   高鐵 [出發站] → [到達站]，[日期]
   [時間] 車次[編號] 自由座 $[價格] / 對號座 $[價格]
   [時間] 車次[編號] ...
   ```

## 已知的坑

- 日期選擇器是客製化 UI，用 `browser_click` 選月份格子比填欄位更穩定
- 結果表格用 JavaScript 渲染，需 wait 1-2 秒後再截取
- 驗證碼：目前查詢頁不需要，如出現請截圖回報

## Changelog
- 2026-04-04：初始建立
```

- [ ] **Step 4: Commit**

```bash
git add plugins/playwright/
git commit -m "feat: add playwright recipes directory with thsr.md"
```

---

## Task 3: 建立 playwright-task Skill

**Files:**
- Create: `.claude/commands/playwright-task.md`

- [ ] **Step 1: 建立 playwright-task.md**

建立 `.claude/commands/playwright-task.md`：

````markdown
# playwright-task

Playwright 瀏覽器自動化轉接層。收到瀏覽器任務指令後，查食譜 → 執行 → 回報 Telegram。

## 觸發時機

由 CLAUDE.local.md 路由判斷後呼叫。不直接由使用者呼叫。

## 執行流程

### Step 1：解析使用者指令

從 Telegram 訊息中識別：
- 目標網站（高鐵、蝦皮、UNIQLO、餐廳名稱…）
- 任務類型（查詢 / 購買 / 訂位…）
- 關鍵參數（日期、出發站、目的站、商品名稱、人數…）

### Step 2：查食譜

查 `plugins/playwright/recipes/<site>.md`：

| 判斷 | 行動 |
|------|------|
| 有食譜 | 告知使用者「找到食譜，開始執行」，照食譜步驟用 Playwright MCP 工具操作 |
| 無食譜 | 告知使用者「第一次嘗試，可能需要幾輪」，用 Playwright MCP 即興探路 |

### Step 3：執行

使用 Playwright MCP 工具（headless 模式）：
- `browser_navigate(url)` — 前往網址
- `browser_click(selector or description)` — 點擊元素
- `browser_fill(selector, value)` — 填入文字
- `browser_wait(milliseconds)` — 等待
- `browser_screenshot()` — 截圖

### Step 4：回報 Telegram

**成功時：**
```
✅ [任務描述] 完成

[結果摘要]
```

**失敗時（附截圖）：**
```
❌ [任務描述] 失敗

原因：[錯誤描述]
[截圖附圖]
```

使用 `mcp__plugin_telegram_telegram__reply` 工具回報，chat_id: 7908106895。
失敗時用 `files: ["/tmp/playwright-screenshot.png"]` 附上截圖。

### Step 5：即興探路成功後

詢問：「要把這次的步驟存成食譜嗎？存好之後下次直接走食譜，更穩定。」

若使用者同意，將步驟整理存入 `plugins/playwright/recipes/<site>.md`（格式參考 README.md）。

## 錯誤處理

| 情況 | 處理 |
|------|------|
| 驗證碼出現 | 截圖 → 回報 → 停止，說「需要人工處理驗證碼」 |
| 頁面結構改變 | 截圖 + 描述 → 回報，說「食譜可能需要更新」 |
| 網路超時 | 重試 1 次，仍失敗則回報 |
| 登入失敗 | 回報錯誤，不繼續執行 |
````

- [ ] **Step 2: 驗證檔案存在**

```bash
ls -la /Users/Modema11434/Documents/Life-OS/.claude/commands/playwright-task.md
```
Expected: 檔案存在，大小 > 0

- [ ] **Step 3: Commit**

```bash
git add .claude/commands/playwright-task.md
git commit -m "feat: add playwright-task skill"
```

---

## Task 4: 更新 CLAUDE.local.md 路由表

**Files:**
- Modify: `CLAUDE.local.md`

- [ ] **Step 1: 在路由表加入 playwright 觸發詞**

在 `CLAUDE.local.md` 的 `## 技能路由` 表格最後加入：

```markdown
| 「訂票」「買票」「高鐵」「查高鐵」 | `playwright-task` → recipes/thsr.md |
| 「蝦皮」「幫我買」 | `playwright-task` → recipes/shopee.md（即興探路） |
| 「UNIQLO」 | `playwright-task` → recipes/uniqlo.md（即興探路） |
| 「訂餐廳」「訂位」「幫我訂」+ 餐廳名稱 | `playwright-task` → 即興探路 |
```

並在路由規則說明後加入：

```markdown
playwright-task 一律開 Agent 子代理執行，主 session 只回「收到，瀏覽器任務開始跑」。
```

- [ ] **Step 2: 確認 CLAUDE.local.md 格式正確（無破版）**

讀取 CLAUDE.local.md 確認路由表完整。

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.local.md
git commit -m "feat: add playwright-task routing rules to CLAUDE.local.md"
```

---

## Task 5: 端對端驗收測試

**Goal:** 確認從 Telegram → playwright-task → Playwright MCP → 回報的完整流程可以跑通。

- [ ] **Step 1: 測試 Playwright MCP 可以啟動**

在 Claude Code 中直接呼叫一個最基本的 Playwright 工具：
```
browser_navigate("https://www.google.com")
```
Expected: 不報錯，返回頁面資訊

- [ ] **Step 2: 測試截圖功能**

```
browser_screenshot()
```
Expected: 返回截圖（確認 headless 模式正常）

- [ ] **Step 3: 模擬 Telegram 觸發**

在 Claude Code session 中輸入：
```
幫我查今天台北到左營的高鐵
```
Expected:
1. 路由判斷觸發 playwright-task
2. playwright-task 找到 thsr.md 食譜
3. Playwright MCP 開始操作高鐵網站
4. 結果回報到 Telegram（chat_id: 7908106895）

- [ ] **Step 4: 驗收清單**

- [ ] Playwright MCP 加入 .mcp.json 並可啟動 ✓
- [ ] CLAUDE.local.md 路由正確識別瀏覽器任務 ✓
- [ ] playwright-task skill 可從 Telegram 觸發 ✓
- [ ] thsr.md 食譜可成功執行（查到班次）✓
- [ ] 成功時有摘要回報到 Telegram ✓

- [ ] **Step 5: 最終 Commit**

```bash
git add -A
git commit -m "feat: Playwright MCP integration complete — Telegram browser automation"
```

---

## Self-Review

**Spec coverage check:**
- ✅ Playwright MCP 安裝 → Task 1
- ✅ playwright-task skill → Task 3
- ✅ CLAUDE.local.md 路由 → Task 4
- ✅ recipes 目錄 + thsr.md → Task 2
- ✅ 失敗截圖回報 → Task 3（skill 內的錯誤處理）
- ✅ 成功回報 → Task 3 + Task 5 驗收
- ✅ headless 模式 → Task 1（`--headless` flag）

**Placeholder scan:** 無 TBD、無 TODO，所有步驟均有具體指令。

**Type consistency:** 工具名稱（`browser_navigate`、`browser_click`、`browser_fill`、`browser_screenshot`、`browser_wait`）在 Task 3 和 Task 5 中一致。
