#!/bin/bash
# Version: 1.0
# Last modified: 2026-03-17
# Status: active
# Level: B
# archive-image.sh — 統一歸檔生成圖片到 Obsidian Vault
# 用法：bash archive-image.sh <label> [source_file]
# 輸出：ARCHIVE_URL=<vault_url> ARCHIVE_LOCAL=<local_path>
# source_file 預設 /tmp/gen-image.png

set -euo pipefail

LABEL="${1:-image}"
SOURCE="${2:-/tmp/gen-image.png}"
VAULT_DIR="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault/90_System/Inbox/image-gen"
mkdir -p "$VAULT_DIR"

log() { echo "[$(date +%H:%M:%S)] [ARCHIVE] $*"; }

if [[ ! -f "$SOURCE" ]]; then
  log "❌ 找不到 $SOURCE"
  exit 1
fi

# 本地歸檔（帶日期+label，gen- 前綴）
TODAY_TAG=$(TZ=Asia/Taipei date '+%Y-%m-%d')
SAFE_LABEL=$(echo "$LABEL" | tr ' /:' '-' | head -c 40)
FILENAME="gen-${TODAY_TAG}-${SAFE_LABEL}.png"
LOCAL_FILE="$VAULT_DIR/$FILENAME"

# 避免同名覆蓋
if [[ -f "$LOCAL_FILE" ]]; then
  TIMESTAMP=$(TZ=Asia/Taipei date '+%H%M%S')
  FILENAME="gen-${TODAY_TAG}-${SAFE_LABEL}-${TIMESTAMP}.png"
  LOCAL_FILE="$VAULT_DIR/$FILENAME"
fi

cp "$SOURCE" "$LOCAL_FILE"
log "📁 本地歸檔: $LOCAL_FILE"

# Vault 公開 URL
VAULT_URL="https://vault.life-os.work/90_System/Inbox/image-gen/${FILENAME}"
log "🔗 Vault URL: $VAULT_URL"

# 輸出結果（供呼叫方擷取）
echo "ARCHIVE_LOCAL=$LOCAL_FILE"
echo "ARCHIVE_URL=$VAULT_URL"
