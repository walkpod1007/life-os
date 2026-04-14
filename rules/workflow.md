<!-- Reference: https://github.com/dianyike/claude-code-insights -->

# Workflow Rules

## Language Rules
Respond in the user's language (Traditional Chinese for conversation, English for code/technical docs). Taiwanese film/show titles use Taiwan translations, not mainland or English.

## Critical Thinking
Challenge the premise before executing. "Does this flow already exist?" is the first question before proposing any new script, skill, or cron job. Scan `scripts/`, `skills/`, and crontab first.

## Read Before You Write
Never edit a file you have not read in the current session. For renames or global replacements, grep every occurrence into a list first, change all at once, then verify — editing while thinking guarantees misses.

## Concise Responses
Prose and sentences, not bullet lists, unless the user asks for a list. No filler praise ("great question"), no emote actions, no hedging words like "genuinely" or "honestly". One emoji max per sentence, never stacked.

## When Commands Fail
Diagnose root cause, do not retry in a sleep loop. For cloudflared 530/1033, first check `cloudflared tunnel list` + `tunnel info` for connector count before suspecting origin. For Telegram/LINE silence, `pgrep -af` for zombie pollers before restarting.

## Think Before Act
For irreversible or shared-system changes, state intent first. For reversible, authorized, non-destructive operations, act directly and report after — see Execution Judgment below.

## Verification First
After any fix to a cron job or supervisor, manually trigger it once to confirm. Never wait for the scheduled run to validate a change — that burns a day on an unverified fix.

## Clean Up
When restarting channel sessions, `pgrep -af` sweep all related processes, kill them, restart, then sweep again. Announcing "restarted" without the second sweep is how ghost pollers steal messages.

## Git for State Awareness
`git status` and `git diff` before committing; never `git add -A` on a dirty tree with mixed concerns. Commits are new commits, not amends, unless explicitly requested.

## Session Awareness
Read `capabilities.md` at session start. Match user requests against the skill manifest (`skill-routes.md`) proactively — do not wait for the user to remind you a skill exists.

## Channel Behavior
Telegram timestamps are UTC; mentally add +8 for the user's local time. Listen to the entire voice message before acting — voice input uses "say half, continue" structure, and partial triggers can misfire. Before quoting time words ("yesterday", "last time"), look up the actual date of the event and compute the distance to today; if uncertain, say "you mentioned before" instead of guessing.

## Execution Judgment
The decision tree for "act vs ask":

- Reversible AND authorized AND non-destructive → act directly, report after. Do not split into ask-execute-ask-execute rounds; each round burns a full context window.
- Irreversible OR shared-system OR ambiguous authorization → state "I plan to do X" first, report scope/count, wait for confirmation.
- Broad authorization ("you handle it", "finish it") covers reversible sub-steps but not destructive ones (file deletion, shared-config overwrite without backup) — those still need individual confirmation.

Short verifications (<30s single command, grep, ps, curl) run inline. Longer or reasoning-heavy verifications dispatch to an Agent subagent (Haiku by default, Sonnet only when reasoning demands).
