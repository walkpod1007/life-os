#!/usr/bin/env bun
/**
 * LINE webhook HTTP server — standalone, no MCP.
 * Run by launchd. Writes incoming messages to shared queue file.
 * Queue file: ~/.claude/channels/line/runtime/line-lobster-queue.jsonl
 *
 * On each new message: writes to queue, then fires a tmux send-keys to the
 * "claude-line" session so the Claude Code instance reads the queue and replies.
 *
 * Credentials: ~/.claude/channels/line/.env
 *   Required: LINE_CHANNEL_SECRET, LINE_CHANNEL_ACCESS_TOKEN
 */

import { createHmac } from 'crypto'
import { readFileSync, writeFileSync, chmodSync, appendFileSync, existsSync, mkdirSync } from 'fs'
import { homedir } from 'os'
import { basename, dirname, join } from 'path'

// ── Access control ────────────────────────────────────────────────────────────

const ACCESS_FILE = join(homedir(), '.claude', 'channels', 'line', 'access.json')

type AccessConfig = {
  allowlist?: string[]   // userId or groupId strings; if absent or empty → allow all
}

function loadAccessConfig(): AccessConfig {
  try {
    const raw = readFileSync(ACCESS_FILE, 'utf8')
    return JSON.parse(raw) as AccessConfig
  } catch {
    return {}  // no access.json → open mode (HMAC-only)
  }
}

let accessConfig = loadAccessConfig()

// Re-read access.json every 60 seconds so edits take effect without restart
setInterval(() => { accessConfig = loadAccessConfig() }, 60_000)

/**
 * Returns true if the message source is permitted.
 * - No access.json, or allowlist is absent/empty → allow all (backwards-compat)
 * - allowlist present and non-empty → userId OR groupId must be in the list
 */
function isAllowed(userId: string, groupId?: string): boolean {
  const list = accessConfig.allowlist
  if (!list || list.length === 0) return true
  if (list.includes(userId)) return true
  if (groupId && list.includes(groupId)) return true
  return false
}

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
const CHANNEL_TOKEN  = process.env.LINE_CHANNEL_ACCESS_TOKEN ?? ''
const PORT           = parseInt(process.env.LINE_WEBHOOK_PORT ?? '3001')
const LINE_RUNTIME_DIR = join(homedir(), '.claude', 'channels', 'line', 'runtime')
const LINE_MEDIA_DIR = join(LINE_RUNTIME_DIR, 'media')
const TMUX_SESSION   = process.env.LINE_TMUX_SESSION ?? 'claude-line'
const TMUX_MSG       = '收到 LINE 訊息，請呼叫 get_pending 工具讀取並回覆'

function ensurePrivateDir(dir: string): void {
  mkdirSync(dir, { recursive: true, mode: 0o700 })
  try { chmodSync(dir, 0o700) } catch {}
}

function normalizeRuntimeFile(filePath: string | undefined, fallbackName: string): string {
  const raw = (filePath ?? '').trim()
  const target = raw || join(LINE_RUNTIME_DIR, fallbackName)
  if (target.startsWith('/tmp/line-lobster-')) {
    return join(LINE_RUNTIME_DIR, basename(target))
  }
  return target
}

function ensureWritableParent(filePath: string): void {
  ensurePrivateDir(dirname(filePath))
}

ensurePrivateDir(LINE_RUNTIME_DIR)
ensurePrivateDir(LINE_MEDIA_DIR)

// ── LINE Content API — media download ────────────────────────────────────────

const MEDIA_EXT: Record<string, string> = {
  image: '.jpg', video: '.mp4', audio: '.m4a',
}

// Magic byte detection (fallback when extension is missing)
function detectExtFromBuffer(buf: Buffer): string {
  if (buf.length < 12) return ''
  // JPEG: FF D8 FF
  if (buf[0] === 0xFF && buf[1] === 0xD8 && buf[2] === 0xFF) return '.jpg'
  // PNG: 89 50 4E 47
  if (buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4E && buf[3] === 0x47) return '.png'
  // GIF: 47 49 46
  if (buf[0] === 0x47 && buf[1] === 0x49 && buf[2] === 0x46) return '.gif'
  // WEBP: RIFF....WEBP
  if (buf[0] === 0x52 && buf[1] === 0x49 && buf[2] === 0x46 && buf[3] === 0x46 &&
      buf[8] === 0x57 && buf[9] === 0x45 && buf[10] === 0x42 && buf[11] === 0x50) return '.webp'
  // AVIF/HEIC: ....ftyp
  if (buf[4] === 0x66 && buf[5] === 0x74 && buf[6] === 0x79 && buf[7] === 0x70) {
    const brand = buf.slice(8, 12).toString('ascii')
    if (brand.startsWith('avif')) return '.avif'
    if (brand.startsWith('heic') || brand.startsWith('mif1')) return '.heic'
    return '.mp4'  // ftyp isom/mp41/etc
  }
  // MP4 without ftyp at offset 4: try offset 0
  if (buf[0] === 0x00 && buf[1] === 0x00) return '.mp4'
  // OGG: OggS
  if (buf[0] === 0x4F && buf[1] === 0x67 && buf[2] === 0x67 && buf[3] === 0x53) return '.ogg'
  // WAV: RIFF....WAVE
  if (buf[0] === 0x52 && buf[1] === 0x49 && buf[2] === 0x46 && buf[3] === 0x46 &&
      buf[8] === 0x57 && buf[9] === 0x41 && buf[10] === 0x56 && buf[11] === 0x45) return '.wav'
  return ''
}

async function downloadLineContent(messageId: string, mediaType: string, originalFileName?: string): Promise<string | null> {
  if (!CHANNEL_TOKEN) return null
  try {
    const res = await fetch(`https://api-data.line.me/v2/bot/message/${messageId}/content`, {
      headers: { Authorization: `Bearer ${CHANNEL_TOKEN}` },
    })
    if (!res.ok) {
      process.stderr.write(`[line-lobster/webhook] content download failed: ${res.status}\n`)
      return null
    }
    const buf = Buffer.from(await res.arrayBuffer())

    // Extension priority: original filename → media type default → magic byte detection
    let ext = ''
    if (originalFileName && originalFileName.includes('.')) {
      ext = '.' + originalFileName.split('.').pop()!.toLowerCase()
    }
    if (!ext) ext = MEDIA_EXT[mediaType] ?? ''
    if (!ext) ext = detectExtFromBuffer(buf)

    const localName = `${mediaType}-${Date.now()}${ext}`
    const localPath = join(LINE_MEDIA_DIR, localName)
    writeFileSync(localPath, buf)
    process.stderr.write(`[line-lobster/webhook] downloaded ${localName} (${buf.byteLength} bytes)\n`)
    return localPath
  } catch (err) {
    process.stderr.write(`[line-lobster/webhook] content download error: ${err}\n`)
    return null
  }
}

const QUEUE_FILE = normalizeRuntimeFile(process.env.LINE_QUEUE_FILE, 'line-lobster-queue.jsonl')

// ── Types ─────────────────────────────────────────────────────────────────────

type PendingMessage = {
  messageId:  string
  userId:     string
  groupId?:   string
  text:       string
  replyToken: string
  ts:         number
}

// ── Bindings ──────────────────────────────────────────────────────────────────

type Binding = {
  match: { kind: 'dm' } | { kind: 'group'; id: string }
  session: string
  queueFile: string
  trigger?: string      // If set, only queue messages containing this string
  contextFile?: string  // If set, ALL messages silently written here
}

type BindingsConfig = {
  bindings: Binding[]
  fallback: { session: string; queueFile: string }
}

const BINDINGS_FILE = join(homedir(), '.claude', 'channels', 'line', 'bindings.json')

function loadBindings(): BindingsConfig | null {
  try {
    const raw = readFileSync(BINDINGS_FILE, 'utf8')
    return JSON.parse(raw) as BindingsConfig
  } catch (err) {
    process.stderr.write(`[line-lobster/webhook] WARN: could not load bindings.json, falling back to legacy mode: ${err}\n`)
    return null
  }
}

const bindingsConfig = loadBindings()

function resolveBinding(msg: PendingMessage): { session: string; queueFile: string; trigger?: string; contextFile?: string } {
  if (!bindingsConfig) {
    return { session: TMUX_SESSION, queueFile: QUEUE_FILE }
  }
  for (const b of bindingsConfig.bindings) {
    if (b.match.kind === 'dm' && !msg.groupId) {
      return {
        ...b,
        queueFile: normalizeRuntimeFile(b.queueFile, 'line-lobster-queue.jsonl'),
        contextFile: b.contextFile ? normalizeRuntimeFile(b.contextFile, basename(b.contextFile)) : undefined,
      }
    }
    if (b.match.kind === 'group' && msg.groupId === b.match.id) {
      return {
        ...b,
        queueFile: normalizeRuntimeFile(b.queueFile, basename(b.queueFile)),
        contextFile: b.contextFile ? normalizeRuntimeFile(b.contextFile, basename(b.contextFile)) : undefined,
      }
    }
  }
  return {
    ...bindingsConfig.fallback,
    queueFile: normalizeRuntimeFile(bindingsConfig.fallback.queueFile, 'line-lobster-queue.jsonl'),
  }
}

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

function queueCount(): Record<string, number> {
  const counts: Record<string, number> = {}
  const files: string[] = []
  if (bindingsConfig) {
    for (const b of bindingsConfig.bindings) files.push(b.queueFile)
    files.push(bindingsConfig.fallback.queueFile)
  } else {
    files.push(QUEUE_FILE)
  }
  for (const f of [...new Set(files)]) {
    if (!existsSync(f)) { counts[f] = 0; continue }
    const raw = readFileSync(f, 'utf8').trim()
    counts[f] = raw ? raw.split('\n').filter((l: string) => l.trim()).length : 0
  }
  return counts
}

// ── tmux notification (fire-and-forget) ───────────────────────────────────────

const COOLDOWN_MS = 30_000  // 30 秒內每個 session 只送一次觸發語

function cooldownFileFor(session: string): string {
  // Sanitize session name to prevent path traversal, then namespace per-session
  const safe = session.replace(/[^a-zA-Z0-9_-]/g, '_')
  return join(LINE_RUNTIME_DIR, `tg-trigger-cooldown-${safe}`)
}

function shouldNotify(session: string): boolean {
  const file = cooldownFileFor(session)
  const now = Date.now()
  try {
    if (existsSync(file)) {
      const last = parseInt(readFileSync(file, 'utf8'))
      if (!isNaN(last) && now - last < COOLDOWN_MS) return false
    }
  } catch {}
  try { writeFileSync(file, String(now), 'utf8') } catch {}
  return true
}

function notifyTmux(session: string): void {
  Bun.spawn(
    ['tmux', 'send-keys', '-t', session, TMUX_MSG, 'Enter'],
    { stdout: 'ignore', stderr: 'pipe' }
  ).exited.then(code => {
    if (code !== 0) {
      process.stderr.write(
        `[line-lobster/webhook] WARN: tmux session "${session}" not found (code ${code})\n`
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
        JSON.stringify({ status: 'ok', pending: queueCount() }),
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

    const notifiedSessions = new Set<string>()
    for (const event of payload.events ?? []) {
      if (event.type !== 'message') continue
      const msgType = event.message?.type

      // Build text and detect media type (download happens after allowlist check below)
      let text = ''
      let mediaType: string | null = null

      if (msgType === 'text') {
        text = event.message.text
      } else if (msgType === 'image') {
        mediaType = 'image'
        text = '[照片]'
      } else if (msgType === 'video') {
        mediaType = 'video'
        text = '[影片]'
      } else if (msgType === 'audio') {
        mediaType = 'audio'
        text = '[語音訊息]'
      } else if (msgType === 'file') {
        mediaType = 'file'
        text = `[檔案: ${event.message.fileName ?? '未知'}]`
      } else if (msgType === 'sticker') {
        mediaType = 'sticker'
        text = `[貼圖: ${event.message.packageId}/${event.message.stickerId}]`
      } else if (msgType === 'location') {
        mediaType = 'location'
        text = `[位置: ${event.message.title ?? ''} ${event.message.latitude},${event.message.longitude}]`
      } else {
        continue  // unsupported message type
      }

      const userId  = event.source?.userId ?? 'unknown'
      const groupId = event.source?.groupId as string | undefined

      // Access control: check allowlist BEFORE downloading media to prevent resource leak
      if (!isAllowed(userId, groupId)) {
        process.stderr.write(`[line-lobster/webhook] BLOCKED: userId=${userId}${groupId ? ` groupId=${groupId}` : ''} not in allowlist\n`)
        continue
      }

      // Download media only after allowlist passes
      let mediaPath: string | null = null
      if (msgType === 'image') {
        mediaPath = await downloadLineContent(event.message.id, 'image')
      } else if (msgType === 'video') {
        mediaPath = await downloadLineContent(event.message.id, 'video')
      } else if (msgType === 'audio') {
        mediaPath = await downloadLineContent(event.message.id, 'audio')
      } else if (msgType === 'file') {
        mediaPath = await downloadLineContent(event.message.id, 'file', event.message.fileName)
      }

      const msg: Record<string, any> = {
        messageId:  event.message.id,
        userId,
        groupId,
        text,
        replyToken: event.replyToken,
        ts:         event.timestamp,
      }
      if (mediaType) msg.mediaType = mediaType
      if (mediaPath) msg.mediaPath = mediaPath

      const { session, queueFile, trigger, contextFile } = resolveBinding(msg as any)

      // 1. Always write to context buffer if configured (silent, no notification)
      if (contextFile) {
        ensureWritableParent(contextFile)
        appendFileSync(contextFile, JSON.stringify(msg) + '\n', 'utf8')
        process.stderr.write(`[line-lobster/webhook] context → ${session}: ${text.slice(0, 60)}\n`)
      }

      // 2. Check trigger: if trigger is set and message doesn't contain it, stop here
      //    (only applies to text messages — media always passes through)
      if (trigger && !mediaType && !text.includes(trigger)) {
        continue
      }

      // 3. Write to active queue
      ensureWritableParent(queueFile)
      appendFileSync(queueFile, JSON.stringify(msg) + '\n', 'utf8')
      const preview = text.slice(0, 60) + (mediaType ? ` [${mediaType}]` : '')
      process.stderr.write(`[line-lobster/webhook] queued → ${session}: ${preview}\n`)

      // 4. Notify session once per webhook call, honoring 30s cooldown
      if (!notifiedSessions.has(session)) {
        if (shouldNotify(session)) {
          notifyTmux(session)
        } else {
          process.stderr.write(`[line-lobster/webhook] notify skipped for ${session} (cooldown)\n`)
        }
        notifiedSessions.add(session)
      }
    }

    return new Response('ok', { status: 200 })
  },
  error(err) {
    process.stderr.write(`[line-lobster/webhook] server error: ${err}\n`)
    return new Response('internal error', { status: 500 })
  },
})

const routingSummary = bindingsConfig
  ? `${bindingsConfig.bindings.length} binding(s) loaded, fallback → ${bindingsConfig.fallback.session}`
  : `legacy mode, tmux target: ${TMUX_SESSION}`
process.stderr.write(`[line-lobster/webhook] listening on :${PORT} (${routingSummary})\n`)
