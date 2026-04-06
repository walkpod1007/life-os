#!/usr/bin/env bun
/**
 * qmd-search MCP server — 讓 Claude Code session 可以搜尋 Vault / daily slices / memory
 * 底層呼叫 qmd CLI（BM25 快速搜尋 + 語意搜尋）
 *
 * Tools:
 *   - vault_search: 快速關鍵字搜尋（BM25，秒回）
 *   - vault_query:  深度語意搜尋（向量 + HyDE expand，10-20 秒）
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js'
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js'
import {
  ListToolsRequestSchema,
  CallToolRequestSchema,
} from '@modelcontextprotocol/sdk/types.js'

// ── qmd wrapper ──────────────────────────────────────────────────────────────

async function runQmd(args: string[]): Promise<string> {
  const proc = Bun.spawn(['/opt/homebrew/bin/qmd', ...args], {
    stdout: 'pipe',
    stderr: 'pipe',
    env: {
      ...process.env,
      PATH: '/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin',
    },
  })

  const stdout = await new Response(proc.stdout).text()
  const stderr = await new Response(proc.stderr).text()
  const exitCode = await proc.exited

  if (exitCode !== 0) {
    throw new Error(`qmd exited ${exitCode}: ${stderr.trim()}`)
  }

  return stdout.trim()
}

function extractDateFromBlock(block: string): string | null {
  // Try path-based date: daily/2026-04-04/0107-session.md → [2026-04-04 01:07]
  const dailyMatch = block.match(/daily\/(\d{4}-\d{2}-\d{2})\/(\d{2})(\d{2})-/)
  if (dailyMatch) {
    return `${dailyMatch[1]} ${dailyMatch[2]}:${dailyMatch[3]}`
  }

  // Try frontmatter date + time in context: date: 2026-04-04 / time: 01:08
  const dateMatch = block.match(/date:\s*(\d{4}-\d{2}-\d{2})/)
  const timeMatch = block.match(/time:\s*(\d{2}:\d{2})/)
  if (dateMatch) {
    return timeMatch ? `${dateMatch[1]} ${timeMatch[1]}` : dateMatch[1]
  }

  // Try filename date: 2026-04-06-norbert-wiener-...-dream.md
  const fileMatch = block.match(/(\d{4}-\d{2}-\d{2})-[a-z]/)
  if (fileMatch) {
    return fileMatch[1]
  }

  return null
}

function formatResults(raw: string, maxResults: number): string {
  // qmd output: blocks separated by double newlines
  // Each block has: path, title, score, context lines
  const blocks = raw.split(/\n\n+/).filter(b => b.trim())
  const limited = blocks.slice(0, maxResults)

  if (limited.length === 0) {
    return '搜尋無結果。'
  }

  return limited.map(block => {
    const date = extractDateFromBlock(block)
    return date ? `[${date}]\n${block}` : block
  }).join('\n\n---\n\n')
}

// ── MCP Server ───────────────────────────────────────────────────────────────

const mcpServer = new Server(
  { name: 'qmd-search', version: '0.1.0' },
  {
    capabilities: { tools: {} },
    instructions: `Vault 記憶搜尋工具。當你需要回憶過去的對話、查找使用者說過的事、找之前的解法或決策時使用。
vault_search 秒回，適合先試；vault_query 更準但要 10-20 秒，找不到時再用。`,
  }
)

mcpServer.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: 'vault_search',
      description:
        '快速搜尋 Vault / daily slices / memory / skills（BM25 關鍵字，秒回）。' +
        '適合：找特定事件、工具名、錯誤訊息、人名。' +
        '用繁中或英文關鍵字皆可。',
      inputSchema: {
        type: 'object',
        properties: {
          query: { type: 'string', description: '搜尋關鍵字' },
          max_results: {
            type: 'number',
            description: '最多回傳幾筆（預設 5）',
            default: 5,
          },
        },
        required: ['query'],
      },
    },
    {
      name: 'vault_query',
      description:
        '深度語意搜尋（向量 + HyDE，10-20 秒）。' +
        '適合：模糊回憶、概念性問題、「上次那個 X 怎麼處理的」。' +
        '先試 vault_search，找不到再用這個。',
      inputSchema: {
        type: 'object',
        properties: {
          query: { type: 'string', description: '自然語言問題' },
          max_results: {
            type: 'number',
            description: '最多回傳幾筆（預設 3）',
            default: 3,
          },
        },
        required: ['query'],
      },
    },
  ],
}))

mcpServer.setRequestHandler(CallToolRequestSchema, async (req) => {
  const { name, arguments: args } = req.params
  const query = String(args?.query ?? '').trim()

  if (!query) {
    return { content: [{ type: 'text', text: 'ERROR: query 不能為空' }] }
  }

  const maxResults = Number(args?.max_results) || (name === 'vault_query' ? 3 : 5)

  if (name === 'vault_search') {
    try {
      const raw = await runQmd(['search', query])
      const formatted = formatResults(raw, maxResults)
      return { content: [{ type: 'text', text: formatted }] }
    } catch (err) {
      return { content: [{ type: 'text', text: `vault_search 失敗: ${err}` }] }
    }
  }

  if (name === 'vault_query') {
    try {
      const raw = await runQmd(['query', query])
      const formatted = formatResults(raw, maxResults)
      return { content: [{ type: 'text', text: formatted }] }
    } catch (err) {
      return { content: [{ type: 'text', text: `vault_query 失敗: ${err}` }] }
    }
  }

  throw new Error(`Unknown tool: ${name}`)
})

const transport = new StdioServerTransport()
await mcpServer.connect(transport)
