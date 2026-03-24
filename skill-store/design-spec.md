# Skill Store — 視覺規格 v1.0

> 此文件是 UI（story 3）和 icon 生成（story 4）的共同依據。
> 參考：Codex Skill Store 截圖（2026-03-24）

---

## 色彩系統

| 用途 | 色值 | 說明 |
|------|------|------|
| 背景 | `#0d0d0d` | 頁面底色，接近純黑 |
| 卡片背景 | `#1a1a1a` | 卡片底色，略淺於頁面 |
| 卡片 hover | `#242424` | 滑入高亮 |
| 卡片邊框 | `#2a2a2a` | 1px 細邊框 |
| 文字主色 | `#f0f0f0` | 技能名稱 |
| 文字次色 | `#888888` | 描述文字 |
| 頂欄底色 | `#111111` | 固定頂欄背景 |
| 強調色 | `#5e9ef4` | 搜尋框 focus、已安裝打勾 |
| 新增按鈕 | `#3a7bd5` | + 新增技能按鈕 |

---

## 字型

- 字體：`-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif`
- 技能名稱：`16px, font-weight: 600`
- 描述：`13px, font-weight: 400`
- 頂欄標題：`22px, font-weight: 700`
- 副標題：`13px, color: #888`

---

## 卡片規格

```
┌─────────────────────────────────────────┐
│  [icon 56x56]  技能名稱（粗體）      ✓  │
│                描述文字（單行截斷）      │
└─────────────────────────────────────────┘
```

| 屬性 | 值 |
|------|-----|
| 卡片寬度 | 自適應（CSS Grid 雙欄） |
| 卡片高度 | `72px`（固定） |
| 卡片圓角 | `12px` |
| 卡片內距 | `12px 16px` |
| icon 尺寸 | `56x56px` |
| icon 圓角 | `14px`（iOS 圓角比例） |
| icon 與文字間距 | `14px` |
| 文字區塊 | flex column，垂直置中 |
| 打勾圖示 | 右側，`16px`，`color: #5e9ef4` |

---

## Icon 規格（供 imagen-gen 使用）

| 屬性 | 值 |
|------|-----|
| 輸出尺寸 | `512x512px`（顯示縮放至 56x56） |
| 圓角 | `128px`（約 25% of 512，iOS 標準） |
| 背景 | 漸層色（每個 skill 不同色系，見色盤） |
| 符號 | 白色或淺色，居中，清晰 |
| 風格 | 「iOS app icon style, rounded square, gradient background, clean minimal white symbol, flat design, no text」|

**色盤（每個 skill 分配一個色系）：**

| 類別 | 色系 |
|------|------|
| 日常管理（morning-brief, daily-log, life-os-checklist） | 暖橘 / 金黃 |
| 內容抓取（youtube-grabber, podcast-grabber, capture） | 紅 / 粉紅 |
| AI 知識（notebooklm-*） | 藍紫 |
| 居家控制（sonos, smart-home, samsung-*） | 青藍 |
| 社群監控（social-monitor, content-digest） | 綠 |
| 工作流程（pipeline, loop-manager） | 深藍 / 靛 |
| 系統工具（skill-optimizer, telegram-handler） | 灰 / 銀 |
| 週期回顧（insight, week-push） | 紫 |
| 心跳（heartbeat-checkin） | 珊瑚紅 |
| 圖像生成（imagen-gen） | 彩虹漸層 |

---

## 頂欄

```
[重新整理 ↺]   [🔍 搜尋技能...]              [+ 新增技能]
```

| 屬性 | 值 |
|------|-----|
| 高度 | `56px` |
| 位置 | sticky top |
| 搜尋框寬度 | `280px`，圓角 `8px` |
| 搜尋框背景 | `#2a2a2a` |
| 按鈕圓角 | `8px` |

---

## 格線

| 屬性 | 值 |
|------|-----|
| 佈局 | CSS Grid |
| 欄數 | 2（桌面）/ 1（< 640px） |
| 間距 | `gap: 8px` |
| 外距 | `padding: 16px 24px` |

---

## 互動效果

- 卡片 hover：背景色 `#1a1a1a → #242424`，`transition: 0.15s`
- 搜尋框 focus：邊框 `1px solid #5e9ef4`
- 打勾：已安裝 `✓ #5e9ef4`，未安裝空白
