---
name: telegram-output
description: |
  選擇 Telegram 回覆格式。文字、按鈕、語音、檔案。
  
  觸發：需要回覆 Telegram 訊息時，由回應流程呼叫以選擇輸出格式。
  不觸發：要回覆 LINE（用 line-output）、媒體路由決策（由 telegram-dispatcher 負責）、要主動推播（用 Push API）。
  消歧：此 skill 只做輸出格式選擇，不做分流決策。
metadata: {"clawdbot":{"emoji":"📤"}}
---

# Telegram 輸出能力邊界（telegram-output）

> 觸發時機：需要選擇最適合的 Telegram 回覆方式時（文字 / 圖片 / 語音 / 按鈕 / 媒體）

---

## Telegram 能做 ✅ 和不能做 ❌

| 能做 | 不能做 |
|------|--------|
| HTML 格式化文字（粗體/斜體/連結/code）| `[[buttons:]]` 語法（LINE 專用）|
| Inline Keyboard 按鈕（透過 CLI）| Flex Message 卡片（LINE 專用）|
| 語音訊息（`[[audio_as_voice]]`）| editMessage 做按鈕 feedback（~5 秒延遲，不建議）|
| 圖片/檔案直接上傳（本地路徑或 URL）| Quick Reply 泡泡（LINE 專用）|
| 超連結含 link preview | PDF 預覽（需手動下載）|
| Streaming 即時預覽（自動啟用）| 確認已讀 |
| 投票 Poll | 超過 4000 字單則訊息（需分段）|
| Sticker（需啟用 actions.sticker）| |
| Reaction（👀 ACK 等）| |
| `[[reply_to_current]]` 回覆串 | |

---

## 輸出方式選擇原則

### 純文字（最常用）
**適用：任何一般對話、簡短回答、清單說明**

Telegram 原生支援 HTML 格式：
- 粗體：`**text**` → 自動轉 `<b>text</b>`
- 斜體：`_text_` → 自動轉 `<i>text</i>`
- 程式碼：`` `code` `` → `<code>code</code>`
- 連結：`[text](url)` → 自動轉 Telegram 超連結
- Code block：\`\`\`語言\n...\`\`\` → 正常渲染（Telegram 支援！）

**超過 4000 字自動分段**（`textChunkLimit: 4000`）

絕對不在 Telegram 輸出：
- JSON 原始格式（除非用戶明確要求）
- Stack trace 完整堆疊（用 code block 包並摘要）

---

### Inline Keyboard 按鈕
**適用：需要用戶做選擇的場景（確認操作 / 多選項 / 快速回覆）**

⚠️ 必須透過 `exec` 呼叫 CLI，不能用 `[[buttons:]]` 語法（Telegram 不支援）

```bash
openclaw message send \
  --channel telegram \
  --target <chatId> \
  --message "請選擇操作：" \
  --buttons '[
    [{"text":"✅ 確認","callback_data":"confirm"},{"text":"❌ 取消","callback_data":"cancel"}],
    [{"text":"📋 查看詳情","callback_data":"detail"}]
  ]'
```

按鈕點擊後 agent 收到：`callback_data: <value>`（當作一般訊息處理）

**按鈕排版原則：**
- 一行最多 2-3 個按鈕（超過會被截斷）
- 按鈕文字簡短（建議 < 20 字）
- callback_data 用小寫英文或 snake_case（方便處理）
- 不做 editMessage 更新按鈕狀態（延遲 ~5 秒，體驗差）

**不需要按鈕的場景：**
- 純資訊回覆
- 操作已完成無需確認
- 答案是開放式輸入

---

### 語音訊息
**適用：用戶要求「唸給我聽」，或語音更自然的回覆**

在回覆文字中加入 `[[audio_as_voice]]` tag，OpenClaw 自動以 voice note 格式送出：

```
[[audio_as_voice]]
這是要轉成語音的內容。
```

或用 message action：
```json
{
  "action": "send",
  "channel": "telegram",
  "to": "123456789",
  "media": "/path/to/audio.ogg",
  "asVoice": true
}
```

---

### 圖片 / 檔案上傳
**適用：分享截圖、生成圖片、傳送文件**

Telegram 支援直接上傳本地檔案，不需要公開 URL（但也接受 URL）：

```bash
# 上傳本地圖片
openclaw message send \
  --channel telegram \
  --target <chatId> \
  --media /path/to/image.png \
  --message "這是圖片說明"

# 用 URL
openclaw message send \
  --channel telegram \
  --target <chatId> \
  --media "https://example.com/image.jpg"
```

inbound 媒體自動存到：`~/Documents/life-os/media/inbound/`

---

### 影片訊息
**適用：傳送影片，或圓形 Video Note**

```json
{
  "action": "send",
  "channel": "telegram",
  "to": "123456789",
  "media": "/path/to/video.mp4",
  "asVideoNote": true
}
```

⚠️ Video note 不支援 caption，文字需另外傳送

---

### Poll 投票
**適用：需要多人投票決策**

```bash
openclaw message poll \
  --channel telegram \
  --target <chatId> \
  --poll-question "要做哪個功能？" \
  --poll-option "功能 A" \
  --poll-option "功能 B" \
  --poll-option "功能 C"
```

---

## 長任務處理原則

**Streaming 預覽（已自動啟用）**
OpenClaw 預設 `streaming: "partial"`，回覆生成時用戶看到即時更新。不需要手動送「處理中...」訊息。

**長任務（> 30 秒）：**
先送一則確認文字，再用 background exec 執行：
```
"收到，開始處理（可能需要幾分鐘）..."
```
然後 `exec(background=true)` 跑任務，完成後再送結果。

**不建議 editMessage 做 feedback：**
技術可行但延遲 ~5 秒，用戶體驗差。

---

## Reaction ACK

快速確認收到用戶訊息，用 emoji reaction 取代 loading text：
- 預設 ACK emoji：agent identity emoji 或 👀
- 設定：`channels.telegram.ackReaction`

---

## Reply Threading

需要明確回覆某則訊息時，在回覆開頭加：
- `[[reply_to_current]]` — 回覆觸發這次對話的訊息
- `[[reply_to:<message_id>]]` — 回覆特定 message ID

---

## 格式選擇速查

| 場景 | 格式 |
|------|------|
| 一般對話 | 純文字（可含 HTML 格式）|
| 清單 / 步驟說明 | 純文字 + `•` 或數字 |
| 程式碼 | \`\`\`language code\`\`\` |
| 需要用戶選擇 | Inline Keyboard（CLI 送）|
| 語音回覆 | `[[audio_as_voice]]` |
| 傳送圖片/檔案 | media upload（本地路徑或 URL）|
| 多人投票 | Poll CLI |
| 長文（> 4000 字）| 自動分段，或考慮用 Gist + 連結 |

---

## 常用 Chat ID

（根據實際環境填入）

---

## 參考文件

- OpenClaw Telegram 官方文件：`docs/channels/telegram.md`
- 規劃文件：`90_System/Inbox/WP-telegram-skills/README.md`

## Gotchas
- 執行前先確認前置檔案/旗標存在；缺少時直接回報並停止，不要硬做。
- 需要改檔時先備份（.bak），避免錯誤覆寫不可回復。
- 回覆外部訊息前，先完成核心產出檔落地，避免「只說完成但無檔案」。
- 若模型或 API 出現 rate limit / 400 錯誤，改用備援模型並重跑，不要把空跑當成功。
