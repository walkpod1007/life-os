# Playwright MCP Integration — Design Spec

**Date:** 2026-04-04  
**Status:** Approved  
**Author:** Brainstorming session via Telegram

---

## Problem

Life-OS 目前沒有瀏覽器自動化能力。使用者需要手動完成訂票、購物、查資料等重複性瀏覽器任務。

---

## Goal

透過 Telegram 自然語言指令，讓 Claude Code 驅動瀏覽器完成訂票、訂餐廳、蝦皮購物、高鐵查詢、UNIQLO 等任務，結果回報到 Telegram。

---

## Architecture

```
Telegram 訊息（自然語言指令）
    ↓
Claude Code（CLAUDE.local.md 路由判斷）
    ↓
playwright-task skill（轉接層）
    ↓ 查詢 recipes/
有食譜 → 照食譜執行
無食譜 → Playwright 即興探路 → 成功後詢問是否固化食譜
    ↓
Playwright MCP server（@playwright/mcp）
    ↓
headless Chrome（背景執行，失敗時截圖）
    ↓
結果 → Telegram 回報
```

---

## Components

### 1. Playwright MCP Server

**安裝方式：**
```bash
npx @playwright/mcp install
```

**加入 `.mcp.json`：**
```json
{
  "mcpServers": {
    "line-lobster": { ... },
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp"],
      "env": {
        "PLAYWRIGHT_HEADLESS": "true"
      }
    }
  }
}
```

提供工具：`browser_navigate`、`browser_click`、`browser_fill`、`browser_screenshot`、`browser_wait` 等。

---

### 2. playwright-task Skill

**位置：** `.claude/commands/playwright-task.md`

**觸發詞（加入 CLAUDE.local.md）：**

| 觸發條件 | skill |
|---------|-------|
| 「訂票」「買票」「高鐵」 | playwright-task → recipes/thsr.md |
| 「蝦皮」「幫我買」 | playwright-task → recipes/shopee.md |
| 「UNIQLO」 | playwright-task → recipes/uniqlo.md |
| 「訂餐廳」「訂位」 | playwright-task → 即興探路 |
| 「幫我查」+ 需要登入/互動的網站 | playwright-task → 即興探路 |

**執行流程（skill 內部）：**

1. 判斷是否有對應食譜（`plugins/playwright/recipes/<site>.md`）
2. 有食譜 → 照食譜逐步執行
3. 無食譜 → 即興探路（告知使用者「第一次，可能需要幾次嘗試」）
4. 執行模式：headless（預設）
5. 失敗時：截圖 → Telegram 附圖回報錯誤
6. 成功時：摘要回報（例如「已完成，訂位確認號 #12345」）
7. 即興探路成功後：問「要把這個步驟存成食譜嗎？」

---

### 3. Recipe 目錄

**位置：** `plugins/playwright/recipes/`

**每個食譜的格式（`<site>.md`）：**

```markdown
# [網站名稱] — Playwright 食譜

**最後更新：** YYYY-MM-DD
**測試狀態：** ✅ 通過 / ⚠️ 可能需要更新 / ❌ 已失效

## 登入步驟
1. 前往 [URL]
2. 點擊「登入」
3. 填入帳號：[帳號] 密碼：[密碼]（從環境變數讀取）

## 主要操作
（依任務類型分節）

### 查詢票價
...

### 購買
...

## 已知的坑
- 驗證碼：出現時暫停，截圖回報，等待人工確認
- 動態載入：需等待 2 秒後再點擊
- Session 過期：自動重新登入

## Changelog
- YYYY-MM-DD：初始建立
```

---

## Error Handling

| 情況 | 處理方式 |
|------|---------|
| 驗證碼 | 截圖 → Telegram 回報 → 等待人工處理 |
| 頁面結構改變 | 截圖 + 錯誤描述 → Telegram 回報 → 標記食譜需更新 |
| 網路超時 | 重試 1 次，仍失敗則回報 |
| 登入失敗 | 回報錯誤，不繼續執行 |

---

## Success Criteria

- [ ] Playwright MCP 加入 .mcp.json 並可啟動
- [ ] CLAUDE.local.md 路由正確識別瀏覽器任務
- [ ] `playwright-task` skill 可從 Telegram 觸發
- [ ] 第一個食譜（高鐵查詢）可成功執行
- [ ] 失敗時有截圖回報到 Telegram
- [ ] 成功時有摘要回報到 Telegram

---

## Out of Scope（第一版不做）

- 排程自動執行（待第一版穩定後加入 cron）
- 需要 2FA 的網站
- 影片/音訊操作
- 多步驟跨網站任務

---

## Future

- 排程模式：cron 定期觸發常用任務（例如每週一查高鐵票）
- 食譜社群：匯出/分享食譜格式
- 失敗自愈：食譜失效時自動嘗試更新步驟
