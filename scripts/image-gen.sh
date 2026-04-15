#!/bin/bash
# Version: 2.0
# Last modified: 2026-03-19
# Status: active
# Level: B
# image-gen.sh — Gemini 多引擎生圖腳本（零 Push 架構）
# Changelog:
#   v2.0 (2026-03-19): Imagen 4 系列已停用（API quota 歸零），改用 Nano Banana 系列
#                      優先序：Nano Banana Pro → Nano Banana 2 → DALL-E 3
#   v1.0 (2026-03-17): 初版，Imagen 4 三引擎 + DALL-E 3 fallback
# 用法：bash image-gen.sh "<中文描述>" "<PROMPT_LABEL>"
# 結果：存入 /tmp/line-last-imagen.json，並寫入 pending-result.json（type=mediaplayer）
# 由下一則使用者訊息攜帶 reply token 透過 [[media_player:]] 輸出，零 Push

set -euo pipefail

[ -f "$HOME/.claude/.env" ] && source "$HOME/.claude/.env"

PROMPT_ZH="${1:-}"
LABEL="${2:-image}"

LAB="$HOME/Documents/life-os"
GEMINI_KEY="${GEMINI_API_KEY:-}"

log() { echo "[$(date +%H:%M:%S)] [IMAGE-GEN] $*"; }

if [[ -z "$GEMINI_KEY" ]]; then
  log "❌ 找不到 Gemini API Key"
  exit 1
fi

PROMPT_EN="${PROMPT_ZH}, high quality digital art, professional lighting, masterpiece."

# Nano Banana 系列（Gemini generateContent API，支援圖片生成）
# 優先序：Pro（品質高）→ Flash（速度快）
NANO_MODELS=("gemini-3-pro-image-preview" "gemini-3.1-flash-image-preview")
NANO_NAMES=("Nano Banana Pro" "Nano Banana 2")
FINAL_IMAGE_URL=""
USED_ENGINE=""

for i in "${!NANO_MODELS[@]}"; do
  MODEL="${NANO_MODELS[$i]}"
  NAME="${NANO_NAMES[$i]}"
  log "嘗試模型: $NAME ($MODEL) ..."

  RESPONSE=$(GEMINI_API_KEY="$GEMINI_KEY" uv run --with google-genai python3 -c "
import sys, os, json
try:
    from google import genai
    from google.genai import types
    client = genai.Client(api_key=os.environ['GEMINI_API_KEY'])
    response = client.models.generate_content(
        model='$MODEL',
        contents=sys.argv[1],
        config=types.GenerateContentConfig(
            response_modalities=['IMAGE'],
            image_config=types.ImageConfig(image_size='1K')
        )
    )
    for part in response.parts:
        if part.inline_data is not None:
            import base64
            data = part.inline_data.data
            if isinstance(data, str):
                data = base64.b64decode(data)
            with open('/tmp/gen-image.png', 'wb') as f:
                f.write(data)
            print('OK')
            sys.exit(0)
    print('NO_IMAGE')
except Exception as e:
    print(f'ERROR:{e}', file=sys.stderr)
    print('FAIL')
" "$PROMPT_EN" 2>/dev/null || echo "FAIL")

  if [[ "$RESPONSE" == "OK" ]]; then
    log "✅ $NAME 生成成功"
    FINAL_IMAGE_URL="local"
    USED_ENGINE="$NAME"
    break
  else
    log "⚠️ $NAME 失敗，切換下一個..."
  fi
done

# Fallback: DALL-E 3
if [[ -z "$FINAL_IMAGE_URL" ]]; then
  log "🆘 Gemini 全數失效，啟動 DALL-E 3..."
  OPENAI_KEY="${OPENAI_API_KEY:-}"

  if [[ -n "$OPENAI_KEY" ]]; then
    D_RESPONSE=$(curl -s -X POST "https://api.openai.com/v1/images/generations" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $OPENAI_KEY" \
      -d "{\"model\":\"dall-e-3\",\"prompt\":\"$PROMPT_EN\",\"n\":1,\"size\":\"1024x1024\"}")

    FINAL_IMAGE_URL=$(echo "$D_RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin).get('data',[{}])[0].get('url',''))" 2>/dev/null || echo "")
    USED_ENGINE="DALL-E 3"
    # 下載到 /tmp/gen-image.png，確保歸檔和 imgbb 上傳用的是正確的圖
    if [[ -n "$FINAL_IMAGE_URL" ]]; then
      curl -sL "$FINAL_IMAGE_URL" -o /tmp/gen-image.png
    fi
  fi
fi

# 存結果
if [[ -n "$FINAL_IMAGE_URL" ]]; then
  log "🎨 完成 (引擎: $USED_ENGINE)，歸檔中..."

  # 統一歸檔到 Obsidian Vault，取得 vault URL
  ARCHIVE_SCRIPT="$(dirname "$0")/archive-image.sh"
  ARCHIVE_OUT=$(bash "$ARCHIVE_SCRIPT" "$LABEL" /tmp/gen-image.png 2>&1)
  echo "$ARCHIVE_OUT"
  ARCHIVE_URL=$(echo "$ARCHIVE_OUT" | grep "^ARCHIVE_URL=" | sed 's/ARCHIVE_URL=//')
  if [[ -n "$ARCHIVE_URL" ]]; then
    FINAL_IMAGE_URL="$ARCHIVE_URL"
  fi

  log "🎨 完成：$FINAL_IMAGE_URL"
  python3 -c "
import json
result = {
  'url': '$FINAL_IMAGE_URL',
  'engine': '$USED_ENGINE',
  'prompt': $(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$PROMPT_ZH"),
  'label': '$LABEL'
}
with open('/tmp/line-last-imagen.json', 'w') as f:
    json.dump(result, f, ensure_ascii=False)
print('RESULT_URL=' + '$FINAL_IMAGE_URL')
"

  # 零 Push：存入 pending-result，由下一則使用者訊息攜帶 reply token 送出
  PENDING_SCRIPT="$(dirname "$0")/pending-result.sh"
  PENDING_JSON=$(python3 -c "
import json, sys
url, prompt_str, engine = sys.argv[1], sys.argv[2], sys.argv[3]
d = {
  'type': 'mediaplayer',
  'url': url,
  'caption': '生圖完成',
  'prompt': prompt_str,
  'engine': engine,
  'download_url': url
}
print(json.dumps(d, ensure_ascii=False))
" "$FINAL_IMAGE_URL" "$PROMPT_ZH" "$USED_ENGINE")
  bash "$PENDING_SCRIPT" write "$PENDING_JSON" && log "pending-result 已寫入" || log "WARN: pending-result 寫入失敗"
  log "📋 圖片已存 pending-result，等待 reply token 送出"
else
  log "❌ 所有引擎失敗"
  # 寫入 pending-result 以回饋使用者，讓下一則訊息的 reply token 帶出錯誤通知
  PENDING_SCRIPT="$(dirname "$0")/pending-result.sh"
  FAIL_JSON=$(python3 -c "
import json, sys
d = {
  'type': 'error',
  'caption': '生圖失敗：所有引擎（Imagen 4 / DALL-E 3）均無法完成，請稍後再試。',
  'prompt': sys.argv[1]
}
print(json.dumps(d, ensure_ascii=False))
" "$PROMPT_ZH")
  bash "$PENDING_SCRIPT" write "$FAIL_JSON" 2>/dev/null && log "錯誤回饋已寫入 pending-result" || log "WARN: 錯誤回饋寫入失敗"
  exit 1
fi
