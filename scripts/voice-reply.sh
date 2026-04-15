#!/bin/bash
# Version: 1.0
# Last modified: 2026-03-03
# Status: active
# Level: B
# voice-reply.sh — LB-016R TTS 語音回覆 (快速切換版 V4)
# 用法：bash voice-reply.sh "<文字內容>" "<LINE用戶或群組ID>"

set -euo pipefail

[ -f "$HOME/.claude/.env" ] && source "$HOME/.claude/.env"

TEXT="$1"
USER_ID="${2#group:}"  # 移除內部前綴 "group:"，LINE API 只接受純 ID

LAB="$HOME/Documents/life-os"
AUDIO_DIR="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault/90_System/Deliverables/media"
BASE_URL="https://vault.life-os.work/90_System/Deliverables/media"
GENERATED_FOLDER_ID="1tJBWO1QnuJKuIFGDSpSR_JsGPdPTOKai"
LOG="/tmp/voice-reply.log"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

TMP_PREFIX="/tmp/tts-${TIMESTAMP}"
TMP_PAYLOAD="${TMP_PREFIX}-payload.json"
TMP_RESPONSE="${TMP_PREFIX}-response.json"
TMP_PCM="${TMP_PREFIX}.pcm"
TMP_DRIVE="${TMP_PREFIX}-upload.m4a"

FILENAME="tts-${TIMESTAMP}.m4a"
OUTPUT_PATH="$AUDIO_DIR/$FILENAME"
PUBLIC_URL="$BASE_URL/$FILENAME"

cleanup() { rm -f "$TMP_PAYLOAD" "$TMP_RESPONSE" "$TMP_PCM" "$TMP_DRIVE"; }
trap cleanup EXIT

log() { echo "[$(date +%H:%M:%S)] [TTS] $*" | tee -a "$LOG"; }

# ── 讀取金鑰 ─────────────────────────────────────────────
GEMINI_KEY="${GEMINI_API_KEY:-}"
LINE_TOKEN="${LINE_CHANNEL_ACCESS_TOKEN:-}"

[[ -z "$GEMINI_KEY" ]] && { log "ERROR: .gemini-api-key 未設定"; exit 1; }

# ── 零 Push 架構：沒有 REPLY_TOKEN 時直接開始生成，結果存 pending-result ──
# （有 REPLY_TOKEN 時沿用原路徑，直接 reply，零額度消耗）

# ── 生成 TTS Payload ────────────────────────────────────
python3 -c "
import json, sys
text = sys.argv[1]
payload = {
    'contents': [{'role': 'user', 'parts': [{'text': text}]}],
    'generationConfig': {
        'responseModalities': ['AUDIO'],
        'speechConfig': {
            'voiceConfig': {
                'prebuiltVoiceConfig': {'voiceName': 'Aoede'}
            }
        }
    }
}
open(sys.argv[2], 'w').write(json.dumps(payload))
" "$TEXT" "$TMP_PAYLOAD"

# ── 呼叫 Gemini TTS API ──────────────────────────────────
log "呼叫 Gemini TTS API..."
curl -s -X POST \
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-tts:generateContent?key=$GEMINI_KEY" \
    -H "Content-Type: application/json" \
    -d "@${TMP_PAYLOAD}" \
    -o "$TMP_RESPONSE"

# ── 解析音頻 base64 ──────────────────────────────────────
EXTRACT_RESULT=$(python3 -c "
import json, sys
path = sys.argv[1]
r = json.load(open(path))
if 'error' in r:
    print('ERROR:' + r['error'].get('message','?'), file=sys.stderr)
    sys.exit(1)
for part in r.get('candidates',[{}])[0].get('content',{}).get('parts',[]):
    if 'inlineData' in part:
        print(part['inlineData']['data'])
        sys.exit(0)
sys.exit(1)
" "$TMP_RESPONSE" 2>/dev/null || echo "")

if [[ -z "$EXTRACT_RESULT" ]]; then
    log "ERROR: TTS 解析失敗"
    exit 1
fi

# ── 解碼 PCM → m4a (ffmpeg, L16 big-endian 24kHz mono) ────
log "格式轉換 (L16 PCM→m4a via ffmpeg)..."
printf '%s' "$EXTRACT_RESULT" | base64 -d > "$TMP_PCM"

ffmpeg -y -f s16le -ar 24000 -ac 1 -i "$TMP_PCM" -c:a aac -b:a 128k "$OUTPUT_PATH" 2>/dev/null

# ── 取得時長 ──────────────────────────────────────────────
DURATION_MS=$(afinfo "$OUTPUT_PATH" 2>/dev/null | python3 -c "
import sys, re
for l in sys.stdin:
    m = re.search(r'estimated duration: ([\d.]+)', l)
    if m:
        print(min(int(float(m.group(1))*1000), 300000)); break
else:
    print(30000)
" || echo "30000")

# ── 上傳至 catbox.moe ─────────────────────────────────────
log "上傳至 catbox.moe..."
CATBOX_URL=$(curl -s -F "reqtype=fileupload" -F "fileToUpload=@${OUTPUT_PATH}" \
    https://catbox.moe/user/api.php --max-time 30 || echo "")

if [[ "$CATBOX_URL" == https://* ]]; then
    PUBLIC_URL="$CATBOX_URL"
    log "✅ catbox.moe 上傳成功: $PUBLIC_URL"
else
    log "⚠️ catbox.moe 失敗，切換至 Drive..."
    cp "$OUTPUT_PATH" "$TMP_DRIVE"
    UPLOAD_RESULT=$(gog drive upload "$TMP_DRIVE" --parent "$GENERATED_FOLDER_ID" --json 2>/dev/null || echo "{}")
    FILE_ID=$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get('file',{}).get('id',''))" "$UPLOAD_RESULT" 2>/dev/null || echo "")
    if [[ -n "$FILE_ID" ]]; then
        gog drive share "$FILE_ID" --to=anyone --role=reader 2>/dev/null
        PUBLIC_URL="https://drive.google.com/uc?export=download&id=${FILE_ID}&confirm=1"
        log "✅ 使用 Drive 備援"
    fi
fi

# ── 傳送 LINE audio ───────────────────────────────────────
log "傳送 LINE 語音 (URL: $PUBLIC_URL)..."

if [[ -n "${REPLY_TOKEN:-}" ]]; then
  # Reply API：一次帶兩則（Flex 說明卡 + audio），零額度消耗
  REPLY_PAYLOAD=$(python3 -c "
import json, sys
text, reply_token, public_url, duration_ms = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
flex_message = {
    'type': 'flex',
    'altText': '🎙️ 語音訊息',
    'contents': {
        'type': 'bubble',
        'body': {
            'type': 'box', 'layout': 'vertical',
            'contents': [
                {'type': 'text', 'text': '🎙️ 語音訊息', 'weight': 'bold', 'color': '#1DB446'},
                {'type': 'text', 'text': text[:100], 'wrap': True, 'size': 'sm', 'color': '#555555'}
            ]
        }
    }
}
audio_message = {
    'type': 'audio',
    'originalContentUrl': public_url,
    'duration': duration_ms
}
print(json.dumps({'replyToken': reply_token, 'messages': [flex_message, audio_message]}, ensure_ascii=False))
" "$TEXT" "${REPLY_TOKEN}" "$PUBLIC_URL" "$DURATION_MS")
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
      -X POST https://api.line.me/v2/bot/message/reply \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $LINE_TOKEN" \
      -d "$REPLY_PAYLOAD")
else
  # 零 Push 架構：存入 pending-result，由下一則使用者訊息攜帶 reply token 送出
  PENDING_SCRIPT="$(dirname "$0")/pending-result.sh"
  PENDING_JSON=$(python3 -c "
import json, sys
text, url, dur = sys.argv[1], sys.argv[2], int(sys.argv[3])
d = {
  'type': 'audio',
  'url': url,
  'duration_ms': dur,
  'text': text
}
print(json.dumps(d, ensure_ascii=False))
" "$TEXT" "$PUBLIC_URL" "$DURATION_MS")
  bash "$PENDING_SCRIPT" write "$PENDING_JSON" && log "✅ pending-result 已寫入（零 Push）" || log "WARN: pending-result 寫入失敗"
  HTTP_CODE="pending"
fi

[[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "pending" ]] && log "✅ 完成" || log "WARN: LINE HTTP $HTTP_CODE"
