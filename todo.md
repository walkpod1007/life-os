# Todo — 待處理清單

> 更新日期：2026-04-15（搬家後全面刷新）

## P0 — 功能恢復

1. **測試驗收** — LINE 文字/照片、Telegram 文字/語音/react，等 channel 任務跑完後做
2. **缺失腳本還原中** — file-extract.sh / voice-reply.sh / image-gen.sh / security-gate-hook.sh（Opus 執行中）

## P1 — 基礎設施

3. **supervisor 打架根治** — `kill -- -$PGID`、lockf TOCTOU、tmux socket 不一致（研究報告已完成，待執行）
4. **TG_WEBHOOK_SECRET 設定** — 到 `~/.claude/channels/telegram/.env` 加上隨機 secret，更新 Telegram setWebhook

## P2 — 功能擴展（第二輪）

5. **Vault 建構** — Wiki 式建構、Flag 保存、做夢（使用者下一階段主軸）
6. **lobster 公開分享** — 移除 hardcoded `Documents/Life-OS` 路徑、補 README（目前是個人用，要做成可分享版）

## 待決策（需使用者輸入）

7. **`claude install`** — Claude Code 提示切 native installer，需跑一次升級
