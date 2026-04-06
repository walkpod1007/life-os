#!/bin/bash
# check-upstream.sh — 檢查官方 telegram plugin 是否有新版本
# 用法：bash ~/Documents/Life-OS/plugins/check-upstream.sh

LOBSTER="$HOME/Documents/Life-OS/plugins/telegram-lobster/server.ts"
CACHE_DIR="$HOME/.claude/plugins/cache/claude-plugins-official/telegram"

LATEST=$(ls -v "$CACHE_DIR" 2>/dev/null | tail -1)

if [ -z "$LATEST" ]; then
  echo "❌ 找不到官方 cache 目錄"
  exit 1
fi

UPSTREAM="$CACHE_DIR/$LATEST/server.ts"

echo "📦 官方最新版本: $LATEST"
echo "🦞 Lobster fork: $LOBSTER"
echo ""

DIFF_COUNT=$(diff "$LOBSTER" "$UPSTREAM" 2>/dev/null | grep -c "^[<>]")

if [ "$DIFF_COUNT" -eq 0 ]; then
  echo "✅ 完全一致，不需要動作"
else
  echo "⚠️  有 $DIFF_COUNT 行差異"
  echo "執行 diff 查看："
  echo "  diff $LOBSTER $UPSTREAM"
fi
