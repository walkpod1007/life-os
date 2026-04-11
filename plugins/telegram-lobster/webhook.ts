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

import { readFileSync, chmodSync, appendFileSync, existsSync, mkdirSync } from 'fs'
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
const SECRET_TOKEN  = process.env.TG_WEBHOOK_SECRET ?? 'tg-lobster-secret'
const TG_RUNTIME    = join(homedir(), '.claude', 'channels', 'telegram', 'runtime')
const QUEUE_FILE    = join(TG_RUNTIME, 'tg-queue.jsonl')
const TMUX_SESSION  = process.env.TG_TMUX_SESSION ?? 'claude-telegram'
const TMUX_MSG      = '收到 Telegram 訊息，請呼叫 telegram-lobster 的 get_pending 工具讀取並用 reply 回覆'

if (!BOT_TOKEN) {
  process.stderr.write('[tg-lobster/webhook] ERROR: missing TELEGRAM_BOT_TOKEN\n')
  process.exit(1)
}

// ── Ensure runtime dir ────────────────────────────────────────────────────────

mkdirSync(TG_RUNTIME, { recursive: true, mode: 0o700 })
try { chmodSync(TG_RUNTIME, 0o700) } catch {}

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
    if (msg?.text && msg?.chat?.id) {
      const entry = {
        updateId:  update.update_id,
        chatId:    msg.chat.id,
        userId:    msg.from?.id ?? null,
        text:      msg.text,
        ts:        msg.date,
        messageId: msg.message_id,
      }
      appendFileSync(QUEUE_FILE, JSON.stringify(entry) + '\n', 'utf8')
      process.stderr.write(`[tg-lobster/webhook] queued from ${entry.chatId}: ${entry.text.slice(0, 60)}\n`)
      notifyTmux()
    } else {
      process.stderr.write(`[tg-lobster/webhook] ignored update type (no text message)\n`)
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
