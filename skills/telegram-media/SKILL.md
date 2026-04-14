---
name: telegram-media
description: >
  處理 Telegram 收到的圖片、語音、影片、檔案、位置。
  觸發：由 telegram-dispatcher 呼叫，對應 mediaType 為 voice/audio/photo/video/document/location。
  不觸發：直接處理純文字（telegram-dispatcher 負責分流）、sticker（telegram-behavior）、主動發送媒體（telegram-output）、LINE 媒體（line-media）。
  消歧：此 skill 只做實際媒體處理（下載、STT、分析），不做分流決策。
metadata: {"clawdbot":{"emoji":"🖼️"}}
---

# Telegram 媒體訊息處理原則（telegram-media）

> 觸發時機：收到任何含媒體的 Telegram 訊息（photo / voice / video / document / audio / sticker / location）

---

## 核心原則

**媒體內容不會過期（Telegram 用 file_id 永久存取），但要立刻回應，不能讓使用者等待。**

Telegram 媒體用 `file_id` 存取，可隨時重新下載。不像 LINE 有 30 分鐘失效限制。
但仍然應該「收到就處理」，避免遺失 context。

---

## 媒體下載方式

```bash
# Step 1: 取得 file_path
BOT_TOKEN=$(grep TELEGRAM_BOT_TOKEN ~/.claude/channels/telegram/.env | cut -d= -f2)
FILE_ID="<file_id from message>"
FILE_INFO=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getFile?file_id=${FILE_ID}")
FILE_PATH=$(echo $FILE_INFO | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['file_path'])")

# Step 2: 下載檔案
curl -s "https://api.telegram.org/file/bot${BOT_TOKEN}/${FILE_PATH}" \
  -o /tmp/openclaw-media-${FILE_ID}
```

Telegram inbound 媒體自動存到：`~/Documents/life-os/media/inbound/`（若 OpenClaw 已配置自動下載）

---

## 多圖緩衝（最高權重）

收到圖片時：
- 30 秒內的圖視為同一批，一起看
- 第一張 → 回一則 Inline Keyboard，不強調數量
- 後續圖片 → 不回應（累積在 context）
- 使用者按 callback_query 或發文字 → 統一處理 context 裡所有圖片
- 不管幾張，一次分析完，不逐張回覆

違反此規則 = 浪費 token + 使用者體驗差。

---

## 各媒體類型處理

### 圖片（message.photo）

Telegram 傳來的 photo 是陣列（多解析度），取最後一個（最大解析度）的 `file_id`。

**收到圖片時，先送 👀 reaction，再發 Inline Keyboard：**

```bash
# 發送 Inline Keyboard
openclaw message send \
  --channel telegram \
  --target <chatId> \
  --message "收到圖片 🖼️ 要怎麼處理？" \
  --buttons '[
    [{"text":"🔍 分析內容","callback_data":"image_analyze"},{"text":"📝 OCR 文字","callback_data":"image_ocr"}],
    [{"text":"🎨 生成類似圖","callback_data":"image_gen"},{"text":"👀 隨便看看","callback_data":"image_browse"}]
  ]'
```

按鈕選項根據圖片類型調整：
- 截圖 / UI / 文字為主 → 顯示「分析內容」「OCR 文字」
- 插畫 / 照片 / AI 生成圖 → 顯示「分析內容」「生成類似圖」「隨便看看」

**禁止：**
- 加前置文字（不說「收到了」「好的」）
- 預覽內容、自動分析、說檔案大小
- 一則 Inline Keyboard 發完就停，等 callback_query

**⚠️ 只處理本次訊息的圖片：**
- 必須有本次傳入的 `file_id`，才算本次
- 對話歷史中的舊圖不描述、不分析

**callback_query 處理（image_analyze）：**
```bash
# 下載圖片到本地後用 image tool 分析
openclaw message send \
  --channel telegram \
  --target <chatId> \
  --message "<分析結果>"
```

---

### 語音訊息（message.voice）

Telegram voice 是 `.ogg`（opus 編碼）。`message.voice.file_id`

**語音對話完整流程：**

Step 1 — ACK（立即）：
送 👀 reaction 或「語音辨識中...」文字

Step 2 — 下載 + 轉檔（~3-5 秒）：
```bash
# 下載 .ogg
curl -s "https://api.telegram.org/file/bot${BOT_TOKEN}/${FILE_PATH}" \
  -o /tmp/tg-voice.ogg

# 轉成 wav（ffmpeg）
ffmpeg -i /tmp/tg-voice.ogg -ar 16000 -ac 1 /tmp/stt-input.wav -y
```

Step 3 — STT（~5 秒）：
```bash
source ~/.claude/.env
curl -s https://api.openai.com/v1/audio/transcriptions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -F model="whisper-1" \
  -F file="@/tmp/stt-input.wav" \
  -F language="zh"
```

Step 4 — 思考回覆（~3 秒）：讀懂內容，生成文字回覆

Step 5 — TTS（選用，若需語音回覆）：
```bash
TIMESTAMP=$(TZ=Asia/Taipei date +%Y%m%d-%H%M%S)
VAULT_MEDIA="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault/60_Deliverables/audio"
curl -s https://api.openai.com/v1/audio/speech \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"tts-1","input":"回覆文字","voice":"nova"}' \
  -o "$VAULT_MEDIA/tts-${TIMESTAMP}.mp3"

# 或直接上傳到 Telegram（不用公開 URL）
openclaw message send \
  --channel telegram \
  --target <chatId> \
  --media "$VAULT_MEDIA/tts-${TIMESTAMP}.mp3" \
  --as-voice true
```

Step 6 — Reply：文字回覆（Telegram 支援直接語音訊息回覆）

**收到語音時的 Inline Keyboard（選擇後續動作）：**

```bash
openclaw message send \
  --channel telegram \
  --target <chatId> \
  --message "語音辨識完成：\n「{辨識結果}」" \
  --buttons '[
    [{"text":"💬 直接回覆","callback_data":"stt_reply"},{"text":"📝 存筆記","callback_data":"stt_to_note"}],
    [{"text":"📌 摘要重點","callback_data":"stt_summary"},{"text":"🔊 語音回覆","callback_data":"stt_voice_reply"}]
  ]'
```

---

### 一般音檔（message.audio）

Telegram audio 是音樂/錄音檔（`.mp3`、`.m4a` 等），與 voice 不同。

- 可轉 STT（同語音流程）
- 通常使用者希望你處理內容（不是只存檔）

---

### 影片（message.video）

- 格式：`.mp4`
- 目前無自動影片分析能力

```bash
openclaw message send \
  --channel telegram \
  --target <chatId> \
  --message "收到影片 🎬 要怎麼處理？" \
  --buttons '[
    [{"text":"💾 下載儲存","callback_data":"video_save"},{"text":"📝 擷取字幕","callback_data":"video_subtitle"}],
    [{"text":"🎞️ 取得縮圖","callback_data":"video_thumbnail"}]
  ]'
```

---

### 文件（message.document）

Telegram document 是通用檔案類型（PDF / DOCX / XLSX / TXT / CSV / JSON / ZIP 等）。

**收到文件時：**

```bash
openclaw message send \
  --channel telegram \
  --target <chatId> \
  --message "收到文件：${FILENAME} 📄" \
  --buttons '[
    [{"text":"📖 讀取內容","callback_data":"file_read"},{"text":"📌 摘要重點","callback_data":"file_summary"}],
    [{"text":"☁️ 存到雲端","callback_data":"file_save"},{"text":"🔍 搜尋內容","callback_data":"file_search"}]
  ]'
```

文件處理工具（callback_query 觸發後）：
```bash
bash ~/Documents/life-os/scripts/file-extract.sh /tmp/{filename}
```

---

### 位置（message.location）

- 包含：`latitude`、`longitude`
- `message.venue`（venue 類型）還含：`title`、`address`、`foursquare_id`

能做：地理查詢、生成 Google Maps URL、距離計算

---

### 貼圖（message.sticker）

- 包含：`file_id`、`emoji`、`set_name`、`is_animated`
- `emoji` 欄位可用於判讀使用者情緒意圖

---

## 處理決策原則

使用者傳媒體，通常是希望你**理解內容**，不是確認收到。

| 媒體類型 | 優先動作 |
|----------|----------|
| 語音/音檔 | 聽懂說了什麼 → STT → 回覆內容 |
| 圖片 | 看懂畫面 → 問意圖（Inline Keyboard）→ 處理 |
| 文件 | 讀懂文件 → 問意圖（Inline Keyboard）→ 摘要或讀取 |
| 影片 | 問意圖（Inline Keyboard）→ 下載或處理 |
| 位置 | 回覆相關地理資訊 / Maps URL |
| 貼圖 | 讀取 emoji 情緒，自然回應 |

---

## Inline Keyboard 替代 LINE buttons

Telegram 沒有 LINE 的 `[[buttons:]]` 語法，一律改用：

```bash
openclaw message send \
  --channel telegram \
  --target <chatId> \
  --message "..." \
  --buttons '[[{"text":"選項A","callback_data":"a"},{"text":"選項B","callback_data":"b"}]]'
```

callback_query 收到後，agent 以一般訊息處理（`callback_query.data` 即為 `callback_data`）。

---

## 參考文件

- telegram-output SKILL.md — 輸出格式選擇
- telegram-behavior SKILL.md — 行為協定（群組/1:1/callback_query 規則）
- `90_System/Inbox/WP-telegram-skills/README.md` — 規劃文件

## Gotchas
- 執行前先確認前置檔案/旗標存在；缺少時直接回報並停止，不要硬做。
- 需要改檔時先備份（.bak），避免錯誤覆寫不可回復。
- 回覆外部訊息前，先完成核心產出檔落地，避免「只說完成但無檔案」。
- 若模型或 API 出現 rate limit / 400 錯誤，改用備援模型並重跑，不要把空跑當成功。
