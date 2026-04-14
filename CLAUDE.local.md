# CLAUDE.local.md — Life OS 專案指令

> 最後更新：2026-04-13

## Session 入口對應表

會跟我對話的入口，tmux session 名字跟管道的對應：

| 你的世界 | tmux session | supervisor 腳本 | 看門狗 |
|---|---|---|---|
| termi（終端機） | **不在 tmux**（前景直跑，讓人直接打字） | `claude-terminal.sh`（或 alias） | ✅ 有狗（token 超過還是要 session-end） |
| LINE DM | claude-line | `claude-line.sh` | ✅ |
| LINE 群（阿普筆記 Cad539…） | claude-line-note | `claude-line-note.sh` | ✅ |
| 手機/Mac App（remote-control） | claude-remote | `claude-remote.sh`（auto `/remote-control`） | ✅ |
| Telegram | claude-telegram | `claude-telegram.sh`（載 telegram-lobster MCP） | ✅ |

**termi 的鐵律**：終端機 session 就是人直接敲鍵盤用的東西，**本來就不在 tmux 裡**（在 tmux 反而沒辦法直接打字）。但 **token-watchdog 照樣要掛**——長對話一樣會炸，到門檻就 session-end 寫 handoff 再重啟。所以看到 `claude-terminal` 不在 `tmux ls` 但 ps 裡有 `token-watchdog.sh claude-terminal` 跑著，這是正常狀態，不是 bug，不要每次檢查都「發現」它然後提議塞進 tmux 或拔狗。

背景 channel（LINE / LINE-note / remote / Telegram）全部被 token-watchdog 罩著，150K token 自動 session-end → 重啟。手動接入：`tmux attach -t <name>`。手動重啟單一條：`bash ~/Documents/Life-OS/scripts/claude-<name>.sh`。

歷史包袱：舊名 claude-life=Telegram、claude-plan=remote、claude-line-test=claude-line-note（2026-04-14 改名）；老的 daily log / handoff / pitfall 卡會看到舊名字。


@/Users/applyao/Documents/life-os/handoff.md

@/Users/applyao/.claude/pitfall-digest.md

@/Users/applyao/Documents/life-os/.claude/capabilities.md

## 技能路由

@/Users/applyao/Documents/life-os/skill-routes.md

## 子代理紅線（核心層保護）

任何子代理（Agent tool 派出的 worker）**禁止寫入**以下核心檔案：

- `soul.md`
- `~/.claude/CLAUDE.md`
- `CLAUDE.local.md`
- `~/.claude/projects/*/memory/MEMORY.md`
- `STATE.md`
- `~/.claude/flag.md`

**允許寫入的工作層：**
- `daily/` 目錄
- `drafts/` 目錄
- `cold-storage/` 目錄
- Obsidian Vault 的 `90-system/inbox/` 和 `30-resources/` 目錄

違反紅線的任務，主 session 要攔截並重新派工，不得讓 worker 自行決定寫入核心層。

