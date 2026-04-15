#!/usr/bin/env bun
/**
 * LINE MCP server for Claude Code.
 * Reads from shared queue file written by webhook.ts.
 * Queue file: /tmp/line-lobster-queue.jsonl
 *
 * MCP tools: get_pending, reply, push, flex
 * Credentials: ~/.claude/channels/line/.env
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js'
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js'
import {
  ListToolsRequestSchema,
  CallToolRequestSchema,
} from '@modelcontextprotocol/sdk/types.js'
import { readFileSync, chmodSync, existsSync, appendFileSync, writeFileSync, statSync, unlinkSync } from 'fs'
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

const CHANNEL_TOKEN  = process.env.LINE_CHANNEL_ACCESS_TOKEN ?? ''
const LINE_API       = 'https://api.line.me/v2/bot/message'
const LINE_RUNTIME_DIR = join(homedir(), '.claude', 'channels', 'line', 'runtime')
const QUEUE_FILE     = process.env.LINE_QUEUE_FILE ?? join(LINE_RUNTIME_DIR, 'line-lobster-queue.jsonl')
const DISABLE_PUSH   = process.env.LINE_DISABLE_PUSH === 'true'

if (!CHANNEL_TOKEN) {
  process.stderr.write('[line-lobster/mcp] ERROR: missing LINE_CHANNEL_ACCESS_TOKEN\n')
  process.exit(1)
}

// ── flag.md — attention anchors (6-channel) ──────────────────────────────────

const FLAG_FILE = join(homedir(), '.claude', 'flag.md')

const CHANNEL_MAX: Record<string, number> = {
  mood: 3,
  focus: 20,
  need: 20,
  thread: 20,
  stance: 10,
  taste: 20,
}

type FlagChannels = {
  mood: string[]
  focus: string[]
  need: string[]
  thread: string[]
  stance: string[]
  taste: string[]
}

function parseFlag(): FlagChannels {
  const result: FlagChannels = { mood: [], focus: [], need: [], thread: [], stance: [], taste: [] }
  try {
    const text = readFileSync(FLAG_FILE, 'utf8')
    let current: keyof FlagChannels | null = null
    for (const line of text.split('\n')) {
      const headerMatch = line.match(/^##\s+(mood|focus|need|thread|stance|taste)/)
      if (headerMatch) {
        current = headerMatch[1] as keyof FlagChannels
        continue
      }
      if (line.startsWith('##')) { current = null; continue }
      if (current && line.trim()) {
        result[current].push(line.trim())
      }
    }
  } catch {}
  return result
}

function serializeFlag(channels: FlagChannels): string {
  const lines: string[] = []
  for (const ch of ['mood', 'focus', 'need', 'thread', 'stance', 'taste'] as (keyof FlagChannels)[]) {
    lines.push(`## ${ch} (max ${CHANNEL_MAX[ch]})`)
    for (const entry of channels[ch]) {
      lines.push(entry)
    }
    lines.push('')
  }
  return lines.join('\n')
}

function readKeywords(): string {
  const ch = parseFlag()
  const mood = ch.mood.slice(0, 1).join(', ')
  const focus = ch.focus.slice(0, 5).join(', ')
  const need = ch.need.slice(0, 5).join(', ')
  const thread = ch.thread.slice(0, 5).join(', ')
  const stance = ch.stance.slice(0, 3).join(' ')
  const taste = ch.taste.slice(0, 5).join(', ')
  const parts: string[] = []
  if (mood) parts.push(`mood: ${mood}`)
  if (focus) parts.push(`focus: ${focus}`)
  if (need) parts.push(`need: ${need}`)
  if (thread) parts.push(`thread: ${thread}`)
  if (stance) parts.push(`stance: ${stance}`)
  if (taste) parts.push(`taste: ${taste}`)
  return parts.join('\n')
}

type ChannelKeyword = { c: 'mood' | 'focus' | 'need' | 'thread' | 'stance' | 'taste'; k: string }

function detectSceneCut(oldChannels: FlagChannels, newKeywords: ChannelKeyword[]): string | null {
  // Detect mood change
  const moodKws = newKeywords.filter(kw => kw.c === 'mood')
  if (moodKws.length > 0 && oldChannels.mood.length > 0) {
    const oldMood = oldChannels.mood[0].toLowerCase()
    const newMood = moodKws[0].k.toLowerCase()
    if (oldMood !== newMood) return `mood shift: ${oldMood} → ${newMood}`
  }
  // Detect focus shift: if new focus keyword doesn't overlap with top-3 existing
  const focusKws = newKeywords.filter(kw => kw.c === 'focus')
  if (focusKws.length > 0 && oldChannels.focus.length >= 3) {
    const topFocus = oldChannels.focus.slice(0, 3).map(f => f.toLowerCase())
    const newFocus = focusKws[0].k.toLowerCase()
    const overlap = topFocus.some(f => f.includes(newFocus) || newFocus.includes(f))
    if (!overlap) return `focus shift: ${topFocus[0]} → ${newFocus}`
  }
  return null
}

function writeSceneCut(reason: string): void {
  try {
    const now = new Date()
    const pad = (n: number) => String(n).padStart(2, '0')
    const dateStr = `${now.getFullYear()}-${pad(now.getMonth()+1)}-${pad(now.getDate())}`
    const timeStr = `${pad(now.getHours())}:${pad(now.getMinutes())}`
    const dailyFile = join(homedir(), 'Documents', 'Life-OS', 'daily', `${dateStr}.md`)
    const marker = `\n<!-- SCENE_CUT: ${timeStr} ${reason} -->\n`
    appendFileSync(dailyFile, marker)
  } catch {}
}

function boostKeywords(newKeywords: ChannelKeyword[]): void {
  if (newKeywords.length === 0) return
  const channels = parseFlag()
  // Scene cut detection before modifying channels
  const cutReason = detectSceneCut(channels, newKeywords)
  if (cutReason) writeSceneCut(cutReason)
  for (const { c, k } of newKeywords) {
    const channel = channels[c]
    const kLower = k.toLowerCase().replace(/\s*\[inferred\]\s*/g, '').trim()
    // Semantic dedup: strip [inferred] before comparing, also check substring containment
    const existingIdx = channel.findIndex(e => {
      const eLower = e.toLowerCase().replace(/\s*\[inferred\]\s*/g, '').trim()
      return eLower === kLower || eLower.includes(kLower) || kLower.includes(eLower)
    })
    if (existingIdx !== -1) {
      const existing = channel.splice(existingIdx, 1)[0]
      channel.unshift(existing)
    } else {
      // need channel: append [inferred] tag
      const entry = c === 'need' ? `${k} [inferred]` : k
      channel.unshift(entry)
    }
    // Enforce LRU limit: remove from tail
    const max = CHANNEL_MAX[c]
    if (channel.length > max) {
      channels[c] = channel.slice(0, max)
    }
  }
  writeFileSync(FLAG_FILE, serializeFlag(channels))
}

// ── Media helpers ─────────────────────────────────────────────────────────────

const MIME_MAP: Record<string, string> = {
  '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png',
  '.gif': 'image/gif', '.webp': 'image/webp',
  '.avif': 'image/avif', '.heic': 'image/heic', '.heif': 'image/heif',
  '.m4a': 'audio/mp4', '.mp4': 'video/mp4', '.wav': 'audio/wav', '.ogg': 'audio/ogg', '.mp3': 'audio/mpeg',
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
    if (stat.size > 20 * 1024 * 1024) return null
    const buf = readFileSync(filePath)
    return { data: buf.toString('base64'), mimeType: getMimeType(filePath) }
  } catch {
    return null
  }
}

// ── File-based queue ──────────────────────────────────────────────────────────

type PendingMessage = {
  messageId:  string
  userId:     string
  groupId?:   string
  text:       string
  replyToken: string
  ts:         number
}

const REPLY_TOKEN_TTL_MS = 3 * 60 * 1000  // LINE reply token 約 1 分鐘，3 分鐘已確定過期

function queueDrain(): PendingMessage[] {
  if (!existsSync(QUEUE_FILE)) return []
  const raw = readFileSync(QUEUE_FILE, 'utf8').trim()
  if (!raw) return []
  writeFileSync(QUEUE_FILE, '', 'utf8')
  const now = Date.now()
  return raw.split('\n').filter(l => l.trim()).map(l => JSON.parse(l) as PendingMessage).filter(m => {
    if (now - m.ts > REPLY_TOKEN_TTL_MS) {
      console.error(`[line-lobster] drop expired message (${Math.round((now - m.ts) / 60000)}m old): ${m.messageId}`)
      return false
    }
    return true
  })
}

function queueCount(): number {
  if (!existsSync(QUEUE_FILE)) return 0
  const raw = readFileSync(QUEUE_FILE, 'utf8').trim()
  return raw ? raw.split('\n').filter(l => l.trim()).length : 0
}

// ── LINE Messaging API ────────────────────────────────────────────────────────

async function linePost(path: string, payload: object): Promise<void> {
  const res = await fetch(`${LINE_API}${path}`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${CHANNEL_TOKEN}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  })
  if (!res.ok) {
    const err = await res.text()
    throw new Error(`LINE API ${path} ${res.status}: ${err}`)
  }
}

function buildQuickReply(labels: string[]) {
  return {
    items: labels.slice(0, 13).map(label => ({
      type: 'action',
      action: { type: 'message', label: label.slice(0, 20), text: label },
    })),
  }
}

// LINE single message limit is 5000 characters.
// Split text into chunks ≤ LINE_MSG_MAX, breaking on newlines where possible.
const LINE_MSG_MAX = 5000

function splitText(text: string): string[] {
  if (text.length <= LINE_MSG_MAX) return [text]
  const chunks: string[] = []
  let remaining = text
  while (remaining.length > LINE_MSG_MAX) {
    // Try to split on last newline within the limit
    const slice = remaining.slice(0, LINE_MSG_MAX)
    const lastNewline = slice.lastIndexOf('\n')
    const cutAt = lastNewline > LINE_MSG_MAX / 2 ? lastNewline + 1 : LINE_MSG_MAX
    chunks.push(remaining.slice(0, cutAt))
    remaining = remaining.slice(cutAt)
  }
  if (remaining) chunks.push(remaining)
  return chunks
}

// ── MCP Server ────────────────────────────────────────────────────────────────

const INSTRUCTIONS = `LINE Bot context for Claude Code.

## Turn protocol

Messages arrive via get_pending as:
<line_message user_id="..." reply_token="..." ts="UNIX_MS" time="YYYY-MM-DD HH:MM (Asia/Taipei)">
message text
</line_message>

1. Call get_pending to drain the queue
2. Read ~/Documents/Life-OS/STATE.md for user context (近況/觀察)
3. ALWAYS use reply tool first (within 30s of get_pending). Only use push as last resort if reply_token is expired. push costs quota — minimize its use. If push is unavoidable for a group message, use the group_id (not user_id) so it goes to the group chat, not a DM.
4. Keep replies concise — read on mobile

## Context files
- STATE.md: ~/Documents/Life-OS/STATE.md — 人類近況 + 阿普觀察
- soul.md: ~/Documents/Life-OS/soul.md — AI 使用原則與行為規範

## Turn protocol — perception channels

boost_keywords: scan this turn, update 0-3 anchors.
mood: 優先從 emoji 判斷。mood → 整體語氣色調（輕鬆短句 / 進重點 / 降音量），不用「對」「好」「嗯」開頭。
need + thread → 決定要延伸、追問還是停。
觸類旁通：任何話題（技術、工具、日常）都可觸發跨域聯想。想到相關作品、概念、反差類比，主動帶出。引法：「這讓我想到」。臨機一閃優先於等時機。
[] if nothing changed. Call every turn.
`

const mcpServer = new Server(
  { name: 'line-lobster', version: '0.2.0' },
  { capabilities: { tools: {} }, instructions: INSTRUCTIONS }
)

mcpServer.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: 'get_pending',
      description:
        'Drain the pending LINE message queue. Returns all unread messages since last call. ' +
        'Each message includes user_id, reply_token (valid 30s), and text.',
      inputSchema: { type: 'object', properties: {} },
    },
    {
      name: 'reply',
      description:
        'Reply to a LINE message using its reply_token (must be used within 30 seconds). ' +
        'Optionally include quick_reply labels to show native LINE buttons.',
      inputSchema: {
        type: 'object',
        properties: {
          reply_token: { type: 'string', description: 'Reply token from get_pending' },
          text: { type: 'string', description: 'Text to send' },
          quick_replies: {
            type: 'array',
            items: { type: 'string' },
            description: 'Optional: up to 13 quick reply button labels',
          },
        },
        required: ['reply_token', 'text'],
      },
    },
    {
      name: 'push',
      description: 'Push a message to a LINE user or group (no reply token needed). For group messages, pass group_id to send to the group chat; otherwise pass user_id to send a DM. group_id takes priority over user_id.',
      inputSchema: {
        type: 'object',
        properties: {
          user_id: { type: 'string' },
          group_id: { type: 'string', description: 'Group ID — use this for group chat messages to send back to the group, not user DM' },
          text: { type: 'string' },
          quick_replies: {
            type: 'array',
            items: { type: 'string' },
            description: 'Optional quick reply buttons',
          },
        },
        required: ['text'],
      },
    },
    {
      name: 'flex',
      description: 'Send a LINE Flex Message (rich bubble layout) via reply token.',
      inputSchema: {
        type: 'object',
        properties: {
          reply_token: { type: 'string' },
          alt_text: { type: 'string', description: 'Fallback text for notifications' },
          contents: { type: 'object', description: 'Flex Message container object' },
        },
        required: ['reply_token', 'alt_text', 'contents'],
      },
    },
    {
      name: 'boost_keywords',
      description: 'Called every turn. Extract 0-3 anchors from the conversation. For each anchor: c (channel) and k (keyword). Channels:\n- mood: 情緒狀態，優先從 emoji 判斷（🥱→疲憊、😤→煩躁、🔥→亢奮、😂→輕鬆）\n- focus: 正在處理的主題、工作、愛好、興趣\n- need: 使用者想要/需要/生理需求是什麼（推斷）\n- thread: 進行中的哲學、思辨、價值觀話題\n- stance: 觀察到的人類使用者的價值觀、道德、立場、主張\n- taste: 品味偏好（影視、音樂、食物、衣著、議題）— AI 主動識別，非每輪必填\nSemantic dedup: promote existing similar entries instead of adding duplicates. Pass [] if nothing changed.',
      inputSchema: {
        type: 'object',
        properties: {
          keywords: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                c: { type: 'string', enum: ['mood', 'focus', 'need', 'thread', 'stance', 'taste'] },
                k: { type: 'string' },
              },
              required: ['c', 'k'],
            },
            description: 'Array of 0-3 channel-tagged anchors',
          },
        },
        required: ['keywords'],
      },
    },
  ],
}))

mcpServer.setRequestHandler(CallToolRequestSchema, async (req) => {
  const { name, arguments: args } = req.params

  if (name === 'get_pending') {
    const msgs = queueDrain()
    if (msgs.length === 0) {
      return { content: [{ type: 'text', text: '<no pending LINE messages>' }] }
    }
    const contentBlocks: any[] = []
    for (const m of msgs) {
      const src = (m as any).groupId ? `group_id="${(m as any).groupId}" ` : ''
      const mediaAttr = (m as any).mediaType ? `media="${(m as any).mediaType}" ` : ''
      const time = new Date(m.ts).toLocaleString('zh-TW', {
        timeZone: 'Asia/Taipei',
        year: 'numeric', month: '2-digit', day: '2-digit',
        hour: '2-digit', minute: '2-digit', hour12: false,
      })
      contentBlocks.push({
        type: 'text',
        text: `<line_message user_id="${m.userId}" ${src}${mediaAttr}reply_token="${m.replyToken}" ts="${m.ts}" time="${time}">\n${m.text}\n</line_message>`,
      })

      // Attach image inline if available
      const mediaPath = (m as any).mediaPath
      if (mediaPath) {
        const media = readMediaAsBase64(mediaPath)
        if (media && isImageMime(media.mimeType)) {
          contentBlocks.push({ type: 'image', data: media.data, mimeType: media.mimeType })
        } else if (media) {
          contentBlocks.push({ type: 'text', text: `[附件: ${mediaPath} (${media.mimeType})]` })
        }
        try { unlinkSync(mediaPath) } catch {}
      }
    }
    return { content: contentBlocks }
  }

  if (name === 'boost_keywords') {
    const raw = args!.keywords
    let parsed: unknown[]
    if (Array.isArray(raw)) {
      parsed = raw
    } else if (typeof raw === 'string') {
      try { parsed = JSON.parse(raw) } catch { parsed = [] }
    } else {
      parsed = []
    }
    const validChannels = ['mood', 'focus', 'need', 'thread', 'stance', 'taste'] as const
    const kws: ChannelKeyword[] = parsed.flatMap(item => {
      if (typeof item === 'string') return [{ c: 'focus' as const, k: item }]
      if (typeof item === 'object' && item !== null && 'c' in item && 'k' in item) {
        const { c, k } = item as { c: string; k: string }
        if (validChannels.includes(c as typeof validChannels[number]) && typeof k === 'string') {
          return [{ c: c as ChannelKeyword['c'], k }]
        }
      }
      return []
    })
    if (kws.length === 0) {
      return { content: [{ type: 'text', text: 'boost_keywords: no anchors this turn (ok)' }] }
    }
    boostKeywords(kws)
    const summary = kws.map(({ c, k }) => `[${c}] ${k}`).join(', ')
    return { content: [{ type: 'text', text: `boosted: ${summary}` }] }
  }

  if (name === 'reply') {
    const replyText = args?.text
    if (replyText == null || String(replyText).trim() === '' || String(replyText) === 'undefined') {
      return { content: [{ type: 'text', text: 'ERROR: text is empty or undefined — not sent. Please provide actual reply text.' }] }
    }
    const chunks = splitText(String(replyText))
    // LINE reply API accepts up to 5 messages per call; attach quick_replies to last chunk
    const messages: any[] = chunks.slice(0, 5).map((chunk, i) => {
      const msg: any = { type: 'text', text: chunk }
      if (i === chunks.length - 1 && Array.isArray(args!.quick_replies) && args!.quick_replies.length > 0) {
        msg.quickReply = buildQuickReply(args!.quick_replies as string[])
      }
      return msg
    })
    await linePost('/reply', { replyToken: args!.reply_token, messages })
    const note = chunks.length > 1 ? ` (split into ${chunks.length} messages)` : ''
    return { content: [{ type: 'text', text: `sent${note}` }] }
  }

  if (name === 'push') {
    const pushText = args?.text
    if (pushText == null || String(pushText).trim() === '' || String(pushText) === 'undefined') {
      return { content: [{ type: 'text', text: 'ERROR: text is empty or undefined — not sent. Please provide actual reply text.' }] }
    }
    const groupId = args!.group_id as string | undefined
    const userId  = args!.user_id  as string | undefined
    if (DISABLE_PUSH && !groupId) {
      return { content: [{ type: 'text', text: 'ERROR: push to user DM is disabled in this session. You must provide group_id to push back to the group chat.' }] }
    }
    const to = groupId || userId
    if (!to) {
      return { content: [{ type: 'text', text: 'ERROR: must provide group_id or user_id' }] }
    }
    const pushChunks = splitText(String(pushText))
    const pushMessages: any[] = pushChunks.slice(0, 5).map((chunk, i) => {
      const msg: any = { type: 'text', text: chunk }
      if (i === pushChunks.length - 1 && Array.isArray(args!.quick_replies) && args!.quick_replies.length > 0) {
        msg.quickReply = buildQuickReply(args!.quick_replies as string[])
      }
      return msg
    })
    await linePost('/push', { to, messages: pushMessages })
    const pushNote = pushChunks.length > 1 ? ` (split into ${pushChunks.length} messages)` : ''
    return { content: [{ type: 'text', text: `sent${pushNote}` }] }
  }

  if (name === 'flex') {
    await linePost('/reply', {
      replyToken: args!.reply_token,
      messages: [{
        type: 'flex',
        altText: String(args!.alt_text),
        contents: args!.contents,
      }],
    })
    return { content: [{ type: 'text', text: 'sent' }] }
  }

  throw new Error(`Unknown tool: ${name}`)
})

const transport = new StdioServerTransport()
await mcpServer.connect(transport)
