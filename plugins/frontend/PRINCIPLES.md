# Frontend 設計原則

## 設計系統

**樣式來源：** `60_Deliverables/dashboards/style.css`（已有 CSS，直接引用）
**輸出位置：** `60_Deliverables/dashboards/<專案名>/index.html`
**存取方式：** `https://vault.life-os.work/60_Deliverables/dashboards/<專案名>/`

### 色彩 Token

```css
--bg: #0a1f14           /* 頁面背景 */
--card-bg: #0f2b1d      /* 卡片背景 */
--text: #f5fff8         /* 主要文字 */
--subtle: #98d7af       /* 次要文字 */
--border: rgba(120,255,170,0.28)  /* 卡片邊框 */
--danger: #ff7d7d       /* 警告/錯誤 */
```

### 版型慣例

- 單欄 grid，gap 14px，padding 14px
- 卡片：border-radius 16px，帶光暈 box-shadow
- 字型：ui-monospace（等寬字族）
- 行動優先：預設寬度 100%，不做 breakpoint 除非明確需要

## 食譜使用方式

1. 選對應食譜（dashboard / report / list / form）
2. 填入食譜的「輸入變數」
3. 派工：主 session 說「用 frontend/recipes/xxx.md 食譜，資料是…」
4. Agent 產出 HTML，放到 60_Deliverables/

## 派工規則

- frontend 任務一律開 Agent 子代理執行
- 主 session 只回「收到，UI 開始產出」
- 子代理只寫 `60_Deliverables/`，不碰其他目錄
