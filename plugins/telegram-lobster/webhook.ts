#!/usr/bin/env bun
/**
 * Telegram webhook HTTP server — standalone, no MCP.
 * Listens on port 8443. Receives Telegram updates via webhook.
 * Writes incoming messages to shared queue file.
 * Queue: ~/.claude/channels/telegram/runtime/tg-queue.jsonl
 *
 * Credentials: ~/.claude/channels/telegram/.env
 *   Required: TELEGRAM_BOT_TOKEN
 */

import { readFileSync, writeFileSync, chmodSync, appendFileSync, existsSync, mkdirSync } from 'fs'
import { homedir } from 'os'
import { join } from 'path'

// ── Credentials ───────────────────────────────────────────────────────────────

const ENV_FILE = join(homedir(), '.claude', 'channels', 'telegram', '.env')
try {
  chmodSync(ENV_FILE, 0o600)
  for (const line of readFileSync(ENV_FILE, 'utf8').split('\n')) {
    const m = line.match(/^(\w+)=(.*)$/)
    if (m && process.env[m[1]] === undefined) process.env[m[1]] = m[2]
  }
} catch {}

const BOT_TOKEN     = process.env.TELEGRAM_BOT_TOKEN ?? ''
const PORT          = parseInt(process.env.TG_WEBHOOK_PORT ?? '8443')
const SECRET_TOKEN  = process.env.TG_WEBHOOK_SECRET ?? (() => {
  process.stderr.write('[tg-lobster/webhook] WARNING: TG_WEBHOOK_SECRET not set — webhook is unprotected. Set this env var in ~/.claude/channels/telegram/.env\n')
  return ''
})()
const TG_CHANNEL_DIR = join(homedir(), '.claude', 'channels', 'telegram')
const TG_RUNTIME    = join(TG_CHANNEL_DIR, 'runtime')
const TG_MEDIA_DIR  = join(TG_RUNTIME, 'media')
const QUEUE_FILE    = join(TG_RUNTIME, 'tg-queue.jsonl')
const ACCESS_FILE   = join(TG_CHANNEL_DIR, 'access.json')
const TMUX_SESSION  = process.env.TG_TMUX_SESSION ?? 'claude-telegram'
const TMUX_MSG      = '收到 Telegram 訊息，請呼叫 telegram-lobster 的 get_pending 工具讀取並用 reply 回覆'

// ── Sender allowlist ──────────────────────────────────────────────────────────
// Reads ~/.claude/channels/telegram/access.json. Supports two field names:
//   - allowlist: string[]   (per upgrade spec)
//   - allowFrom: string[]   (compat with existing official-channel access.json)
// Entries can be user_id (numeric) or username (without @).
// Empty array or missing file → accept all (legacy behavior).
function loadAllowlist(): Set<string> {
  try {
    const raw = readFileSync(ACCESS_FILE, 'utf8')
    const parsed = JSON.parse(raw) as { allowlist?: unknown; allowFrom?: unknown }
    const list = Array.isArray(parsed.allowlist) ? parsed.allowlist
              : Array.isArray(parsed.allowFrom) ? parsed.allowFrom
              : []
    return new Set(list.filter((x): x is string | number => typeof x === 'string' || typeof x === 'number').map(String))
  } catch {
    return new Set()
  }
}

function isAllowed(userId: number | null | undefined, username: string | null | undefined): boolean {
  const allow = loadAllowlist()
  if (allow.size === 0) return true  // empty / missing → allow all
  if (userId != null && allow.has(String(userId))) return true
  if (username && (allow.has(username) || allow.has('@' + username))) return true
  return false
}

if (!BOT_TOKEN) {
  process.stderr.write('[tg-lobster/webhook] ERROR: missing TELEGRAM_BOT_TOKEN\n')
  process.exit(1)
}

// ── Ensure runtime dir ────────────────────────────────────────────────────────

mkdirSync(TG_RUNTIME, { recursive: true, mode: 0o700 })
mkdirSync(TG_MEDIA_DIR, { recursive: true, mode: 0o700 })
try { chmodSync(TG_RUNTIME, 0o700) } catch {}

// ── Telegram file download ───────────────────────────────────────────────────

// Magic byte detection (fallback when extension is missing)
function detectExtFromBuffer(buf: Buffer): string {
  if (buf.length < 12) return ''
  if (buf[0] === 0xFF && buf[1] === 0xD8 && buf[2] === 0xFF) return '.jpg'
  if (buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4E && buf[3] === 0x47) return '.png'
  if (buf[0] === 0x47 && buf[1] === 0x49 && buf[2] === 0x46) return '.gif'
  if (buf[0] === 0x52 && buf[1] === 0x49 && buf[2] === 0x46 && buf[3] === 0x46 &&
      buf[8] === 0x57 && buf[9] === 0x45 && buf[10] === 0x42 && buf[11] === 0x50) return '.webp'
  if (buf[4] === 0x66 && buf[5] === 0x74 && buf[6] === 0x79 && buf[7] === 0x70) {
    const brand = buf.slice(8, 12).toString('ascii')
    if (brand.startsWith('avif')) return '.avif'
    if (brand.startsWith('heic') || brand.startsWith('mif1')) return '.heic'
    return '.mp4'
  }
  if (buf[0] === 0x4F && buf[1] === 0x67 && buf[2] === 0x67 && buf[3] === 0x53) return '.ogg'
  // WAV: RIFF....WAVE
  if (buf[0] === 0x52 && buf[1] === 0x49 && buf[2] === 0x46 && buf[3] === 0x46 &&
      buf[8] === 0x57 && buf[9] === 0x41 && buf[10] === 0x56 && buf[11] === 0x45) return '.wav'
  return ''
}

async function downloadTgFile(fileId: string, prefix: string): Promise<string | null> {
  try {
    const fileRes = await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/getFile`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ file_id: fileId }),
    })
    const fileData = await fileRes.json() as any
    if (!fileData.ok || !fileData.result?.file_path) return null

    const tgFilePath = fileData.result.file_path
    const dlRes = await fetch(`https://api.telegram.org/file/bot${BOT_TOKEN}/${tgFilePath}`)
    if (!dlRes.ok) return null

    const buf = Buffer.from(await dlRes.arrayBuffer())

    // Extension: from Telegram file_path first, then magic byte fallback
    let ext = tgFilePath.includes('.') ? '.' + tgFilePath.split('.').pop() : ''
    if (!ext) ext = detectExtFromBuffer(buf)

    const localName = `${prefix}-${Date.now()}${ext}`
    const localPath = join(TG_MEDIA_DIR, localName)
    writeFileSync(localPath, buf)
    process.stderr.write(`[tg-lobster/webhook] downloaded ${localName} (${buf.byteLength} bytes)\n`)
    return localPath
  } catch (err) {
    process.stderr.write(`[tg-lobster/webhook] file download error: ${err}\n`)
    return null
  }
}

function getFileId(msg: any): string | null {
  if (msg.photo) return msg.photo[msg.photo.length - 1].file_id  // largest size
  if (msg.voice) return msg.voice.file_id
  if (msg.audio) return msg.audio.file_id
  if (msg.video) return msg.video.file_id
  if (msg.document) return msg.document.file_id
  if (msg.sticker) return msg.sticker.file_id
  return null
}

// ── Queue count ───────────────────────────────────────────────────────────────

function queueCount(): number {
  if (!existsSync(QUEUE_FILE)) return 0
  const raw = readFileSync(QUEUE_FILE, 'utf8').trim()
  return raw ? raw.split('\n').filter(l => l.trim()).length : 0
}

// ── tmux notification (fire-and-forget) ───────────────────────────────────────

function notifyTmux(): void {
  Bun.spawn(
    ['tmux', 'send-keys', '-t', TMUX_SESSION, TMUX_MSG, 'Enter'],
    { stdout: 'ignore', stderr: 'pipe' }
  ).exited.then(code => {
    if (code !== 0) {
      process.stderr.write(
        `[tg-lobster/webhook] WARN: tmux session "${TMUX_SESSION}" not found (code ${code})\n`
      )
    }
  }).catch(err => {
    process.stderr.write(`[tg-lobster/webhook] WARN: tmux notify error: ${err}\n`)
  })
}

// ── HTTP Server ───────────────────────────────────────────────────────────────

Bun.serve({
  port: PORT,
  async fetch(req) {
    const url = new URL(req.url)

    if (url.pathname === '/health') {
      return new Response(
        JSON.stringify({ status: 'ok', pending: queueCount(), port: PORT }),
        { headers: { 'Content-Type': 'application/json' } }
      )
    }

    if (url.pathname !== '/webhook') {
      return new Response('not found', { status: 404 })
    }

    if (req.method !== 'POST') {
      return new Response('method not allowed', { status: 405 })
    }

    // Validate secret token header
    const headerSecret = req.headers.get('x-telegram-bot-api-secret-token') ?? ''
    if (headerSecret !== SECRET_TOKEN) {
      process.stderr.write('[tg-lobster/webhook] invalid secret token\n')
      return new Response('Forbidden', { status: 403 })
    }

    let update: any
    try {
      update = await req.json()
    } catch {
      return new Response('bad json', { status: 400 })
    }

    const msg = update?.message
    if (msg?.chat?.id) {
      // Sender allowlist check — silent drop if not allowed
      if (!isAllowed(msg.from?.id, msg.from?.username)) {
        process.stderr.write(
          `[tg-lobster/webhook] dropped (not in allowlist): user_id=${msg.from?.id ?? '?'} username=${msg.from?.username ?? '?'}\n`
        )
        return new Response(JSON.stringify({ ok: true }), {
          headers: { 'Content-Type': 'application/json' }
        })
      }

      // Build text representation for all message types
      let text = msg.text ?? ''
      let mediaType: string | null = null

      if (msg.photo) {
        mediaType = 'photo'
        text = msg.caption ?? '[照片]'
      } else if (msg.voice) {
        mediaType = 'voice'
        text = '[語音訊息]'
      } else if (msg.audio) {
        mediaType = 'audio'
        text = msg.caption ?? `[音訊: ${msg.audio.title ?? msg.audio.file_name ?? '未知'}]`
      } else if (msg.video) {
        mediaType = 'video'
        text = msg.caption ?? '[影片]'
      } else if (msg.document) {
        mediaType = 'document'
        text = msg.caption ?? `[檔案: ${msg.document.file_name ?? '未知'}]`
      } else if (msg.sticker) {
        mediaType = 'sticker'
        text = `[貼圖: ${msg.sticker.emoji ?? ''}]`
      } else if (msg.location) {
        mediaType = 'location'
        text = `[位置: ${msg.location.latitude}, ${msg.location.longitude}]`
      }

      if (!text && !mediaType) {
        process.stderr.write(`[tg-lobster/webhook] ignored update: no text or known media\n`)
      } else {
        // Download media file if present
        let mediaPath: string | null = null
        const fileId = getFileId(msg)
        if (fileId && mediaType) {
          mediaPath = await downloadTgFile(fileId, mediaType)
        }

        const entry: Record<string, any> = {
          updateId:  update.update_id,
          chatId:    msg.chat.id,
          userId:    msg.from?.id ?? null,
          username:  msg.from?.username ?? null,
          text,
          mediaType,
          ts:        msg.date,
          messageId: msg.message_id,
        }
        if (mediaPath) entry.mediaPath = mediaPath

        appendFileSync(QUEUE_FILE, JSON.stringify(entry) + '\n', 'utf8')
        const preview = text.slice(0, 60) + (mediaType ? ` [${mediaType}]` : '')
        process.stderr.write(`[tg-lobster/webhook] queued from ${entry.chatId}: ${preview}\n`)
        notifyTmux()
      }
    } else {
      process.stderr.write(`[tg-lobster/webhook] ignored update: no message or chat\n`)
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { 'Content-Type': 'application/json' }
    })
  },
  error(err) {
    process.stderr.write(`[tg-lobster/webhook] server error: ${err}\n`)
    return new Response('internal error', { status: 500 })
  },
})

process.stderr.write(`[tg-lobster/webhook] listening on :${PORT}\n`)
