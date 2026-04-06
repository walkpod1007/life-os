#!/usr/bin/env bun
/**
 * LINE webhook HTTP server — standalone, no MCP.
 * Run by launchd. Writes incoming messages to shared queue file.
 * Queue file: /tmp/line-lobster-queue.jsonl
 *
 * On each new message: writes to queue, then fires a tmux send-keys to the
 * "claude-line" session so the Claude Code instance reads the queue and replies.
 *
 * Credentials: ~/.claude/channels/line/.env
 *   Required: LINE_CHANNEL_SECRET, LINE_CHANNEL_ACCESS_TOKEN
 */

import { createHmac } from 'crypto'
import { readFileSync, chmodSync, appendFileSync, existsSync } from 'fs'
import { homedir } from 'os'
import { join } from 'path'

// ── Credentials ───────────────────────────────────────────────────────────────

const ENV_FILE = join(homedir(), '.claude', 'channels', 'line', '.env')
try {
  chmodSync(ENV_FILE, 0o600)
  for (const line of readFileSync(ENV_FILE, 'utf8').split('\n')) {
    const m = line.match(/^(\w+)=(.*)$/)
    if (m && process.env[m[1]] === undefined) process.env[m[1]] = m[2]
  }
} catch {}

const CHANNEL_SECRET = process.env.LINE_CHANNEL_SECRET ?? ''
const PORT           = parseInt(process.env.LINE_WEBHOOK_PORT ?? '3001')
const QUEUE_FILE     = process.env.LINE_QUEUE_FILE ?? '/tmp/line-lobster-queue.jsonl'
const TMUX_SESSION   = process.env.LINE_TMUX_SESSION ?? 'claude-line'
const TMUX_MSG       = '收到 LINE 訊息，請呼叫 get_pending 工具讀取並回覆'

if (!CHANNEL_SECRET) {
  process.stderr.write('[line-lobster/webhook] ERROR: missing LINE_CHANNEL_SECRET\n')
  process.exit(1)
}

// ── Signature verification ────────────────────────────────────────────────────

function verifySignature(body: string, signature: string): boolean {
  const expected = createHmac('sha256', CHANNEL_SECRET).update(body).digest('base64')
  return expected === signature
}

// ── Queue ─────────────────────────────────────────────────────────────────────

type PendingMessage = {
  messageId:  string
  userId:     string
  groupId?:   string
  text:       string
  replyToken: string
  ts:         number
}

function queueAppend(msg: PendingMessage): void {
  appendFileSync(QUEUE_FILE, JSON.stringify(msg) + '\n', 'utf8')
}

function queueCount(): number {
  if (!existsSync(QUEUE_FILE)) return 0
  const raw = readFileSync(QUEUE_FILE, 'utf8').trim()
  return raw ? raw.split('\n').length : 0
}

// ── tmux notification (fire-and-forget) ───────────────────────────────────────

function notifyTmux(): void {
  Bun.spawn(
    ['tmux', 'send-keys', '-t', TMUX_SESSION, TMUX_MSG, 'Enter'],
    { stdout: 'ignore', stderr: 'pipe' }
  ).exited.then(code => {
    if (code !== 0) {
      process.stderr.write(
        `[line-lobster/webhook] WARN: tmux session "${TMUX_SESSION}" not found (code ${code})\n`
      )
    }
  }).catch(err => {
    process.stderr.write(`[line-lobster/webhook] WARN: tmux notify error: ${err}\n`)
  })
}

// ── HTTP Server ───────────────────────────────────────────────────────────────

Bun.serve({
  port: PORT,
  async fetch(req) {
    const url = new URL(req.url)

    if (url.pathname === '/health') {
      return new Response(
        JSON.stringify({ status: 'ok', pending: queueCount(), tmuxSession: TMUX_SESSION }),
        { headers: { 'Content-Type': 'application/json' } }
      )
    }

    if (url.pathname !== '/line/webhook') {
      return new Response('not found', { status: 404 })
    }

    if (req.method !== 'POST') {
      return new Response('method not allowed', { status: 405 })
    }

    const body = await req.text()
    const sig  = req.headers.get('x-line-signature') ?? ''

    if (!verifySignature(body, sig)) {
      process.stderr.write('[line-lobster/webhook] invalid signature\n')
      return new Response('Forbidden', { status: 403 })
    }

    let payload: any
    try { payload = JSON.parse(body) } catch {
      return new Response('bad json', { status: 400 })
    }

    let notified = false
    for (const event of payload.events ?? []) {
      if (event.type !== 'message' || event.message?.type !== 'text') continue

      const msg: PendingMessage = {
        messageId:  event.message.id,
        userId:     event.source?.userId ?? 'unknown',
        groupId:    event.source?.groupId,
        text:       event.message.text,
        replyToken: event.replyToken,
        ts:         event.timestamp,
      }

      // 1. Write to queue
      queueAppend(msg)
      process.stderr.write(`[line-lobster/webhook] queued: ${event.message.text.slice(0, 60)}\n`)

      // 2. Notify Claude Code session via tmux (once per webhook call, not per message)
      if (!notified) {
        notifyTmux()
        notified = true
      }
    }

    return new Response('ok', { status: 200 })
  },
  error(err) {
    process.stderr.write(`[line-lobster/webhook] server error: ${err}\n`)
    return new Response('internal error', { status: 500 })
  },
})

process.stderr.write(`[line-lobster/webhook] listening on :${PORT} (tmux target: ${TMUX_SESSION})\n`)
