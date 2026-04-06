# Dashboard — UI 食譜

**用途：** 單頁資訊儀表板，顯示多個資料卡片
**測試狀態：** ✅（life-os、island 儀表板已用此樣式）

## 輸入變數

```
標題：<頁面標題>
副標題：<可選，顯示在標題下方>
卡片清單：
  - 標題：<卡片名稱>
    內容：<文字、清單或表格資料>
    類型：text | list | table | stat
更新時間：<是否顯示「最後更新」時間戳>
```

## 輸出規格

- 引用 `../style.css`（相對路徑）
- 純 HTML，不依賴外部 CDN
- 行動優先，卡片單欄堆疊
- 輸出路徑：`60_Deliverables/dashboards/<名稱>/index.html`

## 卡片類型範例

### stat（單一數字）
```html
<div class="card">
  <div class="card-header"><h2>標題</h2></div>
  <div class="stat-value">數字</div>
  <div class="stat-label">說明</div>
</div>
```

### list（清單）
```html
<div class="card">
  <div class="card-header"><h2>標題</h2></div>
  <ul>
    <li>項目一</li>
    <li>項目二</li>
  </ul>
</div>
```

## 已知的坑

- style.css 路徑用相對路徑 `../style.css`，不要用絕對路徑
- 中文字在 monospace 下寬度是英文兩倍，注意對齊
- 不要內嵌大量 inline style，改 style.css 的 CSS variable 就好

## Changelog
- 2026-04-05：初始建立
