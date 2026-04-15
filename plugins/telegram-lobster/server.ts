#!/usr/bin/env bun
/**
 * Telegram MCP server — queue-based, no grammy.
 * Tools: get_pending, push, reply
 * Queue: ~/.claude/channels/telegram/runtime/tg-queue.jsonl
 *
 * Credentials: ~/.claude/channels/telegram/.env
 *   Required: TELEGRAM_BOT_TOKEN
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js'
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js'
import { ListToolsRequestSchema, CallToolRequestSchema } from '@modelcontextprotocol/sdk/types.js'
import { readFileSync, writeFileSync, existsSync, mkdirSync, chmodSync, renameSync, unlinkSync, statSync } from 'fs'
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

const TOKEN = process.env.TELEGRAM_BOT_TOKEN
if (!TOKEN) {
  process.stderr.write('[tg-lobster/server] ERROR: missing TELEGRAM_BOT_TOKEN\n')
  process.exit(1)
}

// ── Queue ─────────────────────────────────────────────────────────────────────

const TG_RUNTIME = join(homedir(), '.claude', 'channels', 'telegram', 'runtime')
const QUEUE_FILE = join(TG_RUNTIME, 'tg-queue.jsonl')

mkdirSync(TG_RUNTIME, { recursive: true, mode: 0o700 })

function drainQueue(): any[] {
  if (!existsSync(QUEUE_FILE)) return []
  // Atomic drain: rename the queue file first, then read it.
  // webhook.ts will create a new QUEUE_FILE on next append.
  // This eliminates the race window between read and truncate.
  const drainFile = QUEUE_FILE + '.drain'
  try {
    renameSync(QUEUE_FILE, drainFile)
  } catch {
    return []  // file vanished between exists check and rename
  }
  const raw = readFileSync(drainFile, 'utf8').trim()
  try { unlinkSync(drainFile) } catch {}
  if (!raw) return []
  return raw.split('\n').filter(l => l.trim()).map(l => {
    try { return JSON.parse(l) } catch { return null }
  }).filter(Boolean)
}

function formatTime(unixSec: number): string {
  return new Date(unixSec * 1000).toLocaleString('zh-TW', {
    timeZone: 'Asia/Taipei',
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit',
    hour12: false,
  }).replace(/\//g, '-')
}

// ── Media helpers ─────────────────────────────────────────────────────────────

const MIME_MAP: Record<string, string> = {
  '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png',
  '.gif': 'image/gif', '.webp': 'image/webp', '.bmp': 'image/bmp',
  '.avif': 'image/avif', '.heic': 'image/heic', '.heif': 'image/heif',
  '.ogg': 'audio/ogg', '.oga': 'audio/ogg', '.mp3': 'audio/mpeg', '.wav': 'audio/wav',
  '.mp4': 'video/mp4', '.webm': 'video/webm',
  '.pdf': 'application/pdf',
}

function getMimeType(filePath: string): string {
  const ext = filePath.includes('.') ? '.' + filePath.split('.').pop()!.toLowerCase() : ''
  return MIME_MAP[ext] ?? 'application/octet-stream'
}

const CLAUDE_SUPPORTED_IMAGE_TYPES = new Set(['image/jpeg', 'image/png', 'image/gif', 'image/webp'])

function isImageMime(mime: string): boolean {
  return CLAUDE_SUPPORTED_IMAGE_TYPES.has(mime)
}

function readMediaAsBase64(filePath: string): { data: string; mimeType: string } | null {
  try {
    if (!existsSync(filePath)) return null
    const stat = statSync(filePath)
    if (stat.size > 20 * 1024 * 1024) return null  // skip files > 20MB
    const buf = readFileSync(filePath)
    const mimeType = getMimeType(filePath)
    return { data: buf.toString('base64'), mimeType }
  } catch {
    return null
  }
}

// ── Telegram API ──────────────────────────────────────────────────────────────

async function tgApiCall(method: string, body: Record<string, any>): Promise<any> {
  const res = await fetch(`https://api.telegram.org/bot${TOKEN}/${method}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  const data = await res.json() as any
  if (!data.ok) throw new Error(`Telegram API error: ${JSON.stringify(data)}`)
  return data.result
}

// ── MCP Server ────────────────────────────────────────────────────────────────

const server = new Server(
  { name: 'telegram-lobster', version: '1.0.0' },
  { capabilities: { tools: {} } }
)

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: 'get_pending',
      description: 'Read and clear pending Telegram messages from the queue. Returns formatted messages.',
      inputSchema: { type: 'object', properties: {}, required: [] },
    },
    {
      name: 'push',
      description: 'Send a text message to a Telegram chat.',
      inputSchema: {
        type: 'object',
        properties: {
          chat_id: { type: 'number', description: 'Target chat ID' },
          text:    { type: 'string', description: 'Message text to send' },
        },
        required: ['chat_id', 'text'],
      },
    },
    {
      name: 'reply',
      description: 'Reply to a specific Telegram message.',
      inputSchema: {
        type: 'object',
        properties: {
          chat_id:    { type: 'number', description: 'Target chat ID' },
          message_id: { type: 'number', description: 'Message ID to reply to' },
          text:       { type: 'string', description: 'Reply text' },
        },
        required: ['chat_id', 'message_id', 'text'],
      },
    },
    {
      name: 'edit_message',
      description: 'Edit text of a previously-sent bot message. Use for incremental progress updates instead of spamming new messages. Bot can only edit its own messages.',
      inputSchema: {
        type: 'object',
        properties: {
          chat_id:    { type: 'string', description: 'Target chat ID (string form to handle large IDs)' },
          message_id: { type: 'number', description: 'Message ID of the bot message to edit' },
          text:       { type: 'string', description: 'New message text' },
        },
        required: ['chat_id', 'message_id', 'text'],
      },
    },
    {
      name: 'react',
      description: 'Add an emoji reaction to a Telegram message. Telegram only accepts specific emojis from its whitelist (e.g. 👍 ❤️ 🔥 ✅ 👀 🎉). Useful to ack receipt without sending a reply.',
      inputSchema: {
        type: 'object',
        properties: {
          chat_id:    { type: 'string', description: 'Target chat ID (string form to handle large IDs)' },
          message_id: { type: 'number', description: 'Message ID to react to' },
          emoji:      { type: 'string', description: 'Single emoji from Telegram allowed reactions list' },
        },
        required: ['chat_id', 'message_id', 'emoji'],
      },
    },
  ],
}))

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  const { name, arguments: args } = req.params

  if (name === 'get_pending') {
    const messages = drainQueue()
    if (messages.length === 0) {
      return { content: [{ type: 'text', text: '(no pending messages)' }] }
    }
    const contentBlocks: any[] = []
    for (const m of messages) {
      const time = formatTime(m.ts)
      const attrs = [
        `chat_id="${m.chatId}"`,
        `message_id="${m.messageId}"`,
        `user_id="${m.userId}"`,
        m.username ? `username="${m.username}"` : null,
        m.mediaType ? `media="${m.mediaType}"` : null,
        `ts="${m.ts}"`,
        `time="${time}"`,
      ].filter(Boolean).join(' ')
      contentBlocks.push({ type: 'text', text: `<tg_message ${attrs}>\n${m.text}\n</tg_message>` })

      // Attach image inline if available
      if (m.mediaPath) {
        const media = readMediaAsBase64(m.mediaPath)
        const isAudio = m.mediaType === 'voice' || m.mediaType === 'audio'
        if (media && isImageMime(media.mimeType)) {
          contentBlocks.push({ type: 'image', data: media.data, mimeType: media.mimeType })
          // Clean up image after embedding
          try { unlinkSync(m.mediaPath) } catch {}
        } else if (media) {
          contentBlocks.push({ type: 'text', text: `[附件: ${m.mediaPath} (${media.mimeType})]` })
          // Keep audio/voice files so session can run whisper transcription
          if (!isAudio) {
            try { unlinkSync(m.mediaPath) } catch {}
          }
        } else if (!existsSync(m.mediaPath)) {
          contentBlocks.push({ type: 'text', text: `[附件下載失敗: ${m.mediaPath}]` })
        }
      }
    }
    return { content: contentBlocks }
  }

  if (name === 'push') {
    const { chat_id, text } = args as { chat_id: number; text: string }
    await tgApiCall('sendMessage', { chat_id, text })
    return { content: [{ type: 'text', text: `sent to ${chat_id}` }] }
  }

  if (name === 'reply') {
    const { chat_id, message_id, text } = args as { chat_id: number; message_id: number; text: string }
    await tgApiCall('sendMessage', { chat_id, text, reply_to_message_id: message_id })
    return { content: [{ type: 'text', text: `replied to message ${message_id} in chat ${chat_id}` }] }
  }

  if (name === 'edit_message') {
    const { chat_id, message_id, text } = args as { chat_id: string; message_id: number; text: string }
    await tgApiCall('editMessageText', {
      chat_id,
      message_id,
      text,
      parse_mode: 'HTML',
    })
    return { content: [{ type: 'text', text: `edited message ${message_id} in chat ${chat_id}` }] }
  }

  if (name === 'react') {
    const { chat_id, message_id, emoji } = args as { chat_id: string; message_id: number; emoji: string }
    await tgApiCall('setMessageReaction', {
      chat_id,
      message_id,
      reaction: [{ type: 'emoji', emoji }],
    })
    return { content: [{ type: 'text', text: `reacted ${emoji} on message ${message_id} in chat ${chat_id}` }] }
  }

  throw new Error(`Unknown tool: ${name}`)
})

// ── Start ─────────────────────────────────────────────────────────────────────

process.on('unhandledRejection', err => {
  process.stderr.write(`[tg-lobster/server] unhandled rejection: ${err}\n`)
})
process.on('uncaughtException', err => {
  process.stderr.write(`[tg-lobster/server] uncaught exception: ${err}\n`)
})

const transport = new StdioServerTransport()
await server.connect(transport)
process.stderr.write('[tg-lobster/server] MCP server ready (queue-based, no grammy)\n')
