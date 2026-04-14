---
name: session-end
description: Session 結束收尾流程：補尾段摘要 → 更新向量索引 → 寫 handoff.md → 判斷里程碑 → 自重啟。使用時機：要換 session、結束工作、/session-end、寫日檔。
---

# Session End

## Overview

換 session 前的標準收尾，確保記憶完整傳遞，然後自動重啟乾淨 session。

## 執行流程

1. 補尾段摘要
   `bash ~/Documents/Life-OS/scripts/realtime-summary.sh`

2. 更新 Life-OS 向量索引
   `python3 ~/Documents/Life-OS/scripts/lifeos-index-update.py`

3. 寫 handoff.md（覆寫式交接卡）
   覆寫 ~/Documents/Life-OS/handoff.md，格式四段：SUMMARY / CURRENT / NEXT / LESSON
   ⛔ 禁止寫入 memory/ 目錄。如有值得長期保存的 feedback/project/reference 洞察，
   另建對應型別的 memory 卡片（選做，不是必做流程）。

4. 判斷里程碑 → 追加 CHANGELOG.md
   問自己：「這次 session 有完成系統級的基礎建設或變更嗎？下一個我需要知道這件事存在嗎？」
   - 有 → 追加一行到 ~/Documents/Life-OS/CHANGELOG.md 對應日期區塊
   - 沒有 → 跳過（日常對話不寫）
   - 格式：`- [完成] 簡述變更（關鍵細節）`

5. 存 handoff 工單
   寫 ~/Documents/Life-OS/drafts/WO-YYYY-MM-DD-session-handoff.md

6. 自重啟
   `bash ~/Documents/Life-OS/scripts/self-restart.sh &`
   （SessionEnd hook 寫日檔 → 等 30 秒 → kill 當前 session → supervisor 重開）

## 輸出格式

```
Session 收尾完成 ✓

📝 YYYY-MM-DD-HHMM-summary.md 寫入
🔢 Life-OS 向量：N 個入庫
📋 handoff.md 覆寫完成
📋 handoff 工單存檔

待辦帶去下個 session：
• [未完成項目]

重啟中，30 秒後見新 session。
```

## 交接卡品質檢查（借鑑 session-handoff）

寫完交接卡後，執行簡單完整性驗收：

| 項目 | 檢查 |
|------|------|
| 有「做了什麼」 | ✓/✗ |
| 有「現在狀態」 | ✓/✗ |
| 有「下一步」 | ✓/✗ |
| 無明文 token/密碼 | ✓/✗ |

三項以上 ✓ 才算合格，否則補寫後再重啟。

交接卡加上新鮮度標籤：
`## Session 交接（YYYY-MM-DD HH:MM）[FRESH]`

## 原則

- 不重複 SessionEnd hook（hook 負責完整日檔）
- 這個 skill 補「即時摘要尾段 + 向量 + 快速交接卡 + 重啟」
- 自重啟用 & 背景跑，不阻塞輸出
