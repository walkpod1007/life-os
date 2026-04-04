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
