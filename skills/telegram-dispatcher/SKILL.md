---
name: telegram-dispatcher
description: >
  解析每則 Telegram 訊息的類型，路由到對應的處理 skill。
  觸發：每則 Telegram 訊息到達後、telegram-handler 執行完畢時，自動執行。
  不觸發：主動發送訊息（用 telegram-output）、LINE 訊息（用 line-dispatcher）。
  消歧：是路由決策層，不做任何實際處理；處理邏輯在各目的地 skill。
version: "1.0"
created: "2026-04-14"
---

# Telegram Dispatcher

> 執行時機：每則 Telegram 訊息，緊接在 telegram-handler 之後。

每則訊息只做一件事：**看 mediaType 和訊息結構，決定呼叫哪個 skill**。

---

## 路由表

| 條件 | 目的地 skill |
|------|------------|
| `<tg_message mediaType="voice">` 或 `mediaType="audio"` | `telegram-media` → 語音 STT 流程 |
| `<tg_message mediaType="photo">` | `telegram-media` → 圖片 Inline Keyboard 流程 |
| `<tg_message mediaType="video">` | `telegram-media` → 影片流程 |
| `<tg_message mediaType="document">` | `telegram-media` → 文件流程 |
| `<tg_message mediaType="location">` | `telegram-media` → 地理查詢 |
| `<tg_message mediaType="sticker">` | `telegram-behavior` → emoji 情緒回應 |
| `callback_query` | `telegram-behavior` → answerCallbackQuery → 對應動作 |
| 純文字，群組，未被 @ | `group-silence-gating` → 靜默 |
| 純文字，DM | → `skill-routes.md` 觸發條件比對 |

---

## 使用方法

收到 `<tg_message>` tag 時：

1. 讀取 `mediaType` attribute（若有）
2. 對照上方路由表
3. 明確呼叫目的地 skill，傳入完整 message context
4. 不做任何額外處理，dispatcher 不輸出任何訊息給使用者

## 注意事項

- dispatcher 只路由，不處理。不要在這裡寫媒體下載、STT、圖片分析邏輯。
- 收到沒有 `mediaType` 的訊息：先確認是否為 `callback_query`，再判斷群組/DM。
- 未來新增媒體類型：只需在路由表加一列，不動其他 skill。
