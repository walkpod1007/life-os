<!-- Reference: https://github.com/dianyike/claude-code-insights -->

# Security Rules

## Pre-Commit Checks
Before every commit, scan the diff for API keys, tokens, webhook secrets, and absolute paths containing credentials. Never `git add -A` on a dirty tree — stage specific files by name. Files matching `*.env`, `*credentials*`, `*.pem`, `*token*` require explicit user authorization to commit.

## Secret Management
Secrets live in `~/.config/` or shell env vars loaded by supervisor scripts, never in repo files. If a secret is discovered committed, rotate it first, then scrub history — rotation before cleanup, always.

## Destructive Operations
`rm -rf`, `DROP`, `TRUNCATE`, `git reset --hard`, `git push --force`, mass file overwrite — all require stated scope/count and explicit confirmation on the same turn. Broad authorization ("clean it up", "you handle it") does not cover destructive sub-steps. Never force-push to master.

## Security Response Protocol
On discovery of a leaked secret or compromised channel token:
1. Revoke/rotate the credential at the provider immediately
2. Update the local secret store and any supervisor scripts that load it
3. Restart affected sessions with the new credential
4. Document the incident in a pitfall card under `atoms/apu/pitfall/`
5. Only after steps 1–4, consider history scrubbing

## Core File Protection
Subagents (Agent tool workers) are **forbidden** from writing to core files. Main session must intercept and re-dispatch any task that would touch these:

- `soul.md`
- `~/.claude/CLAUDE.md`
- `CLAUDE.local.md`
- `~/.claude/projects/*/memory/MEMORY.md`
- `STATE.md`
- `~/.claude/flag.md`

Worker-allowed write targets: `daily/`, `drafts/`, `cold-storage/`, and Obsidian Vault's `90-system/inbox/` + `30-resources/`.

## Webhook & Supervisor Integrity
Never hardcode `--channels plugin:telegram@...` or any official channel plugin flag in supervisor scripts (`scripts/claude-*.sh`). Before editing any supervisor, grep the full `scripts/` directory for residual plugin flags. Official plugin re-injection on self-restart silently overrides lobster webhook mode and breaks channel routing until manually caught.

## Process Cleanup Verification
After any channel restart (Telegram, LINE, remote-control), always `pgrep -af` scan for related processes before declaring the restart complete. Ghost pollers from prior sessions will steal webhook traffic and make the new session look dead. The sweep is mandatory, not optional.
