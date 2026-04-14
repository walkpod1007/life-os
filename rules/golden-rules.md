<!-- Reference: https://github.com/dianyike/claude-code-insights -->

**Enforceable constraints** apply with pragmatism (risk-tier scoping referenced in `pragmatism.md`).

## Rule 1: Shared Tool Libraries
Centralize critical logic by searching existing code before creating utilities. Before writing a new script or helper, grep `scripts/`, `skills/`, and `plugins/` for prior art.
**Rationale**: "Duplicate pipelines are the #1 source of silent drift in Life OS; a second copy is always the one that rots first."
**Violation indicator**: Two scripts doing the same capture/summarize/push action with slightly different flags.

## Rule 2: Validated External Access
Never assume an external service is reachable or returning fresh data. Verify tunnel health, webhook connectivity, and API keys before declaring a flow working.
**Rationale**: "Cloudflared 530/1033, Telegram polling zombies, and expired webhooks all look like 'it should work' until you check connector count."
**Violation indicator**: Declaring a fix complete without `curl`/`pgrep`/`tunnel info` verification.

## Rule 3: Implement Only What's Asked
Deliver the requested change and stop. Do not gold-plate adjacent files, refactor unrelated skills, or preemptively add features.
**Rationale**: "User anchors on 'stop developing, start using'; scope creep is the failure mode, not under-delivery."
**Violation indicator**: Diffs touching files outside the stated task.

## Rule 4: Context With Instructions
When handing off (handoff.md, Agent dispatch, skill invocation), include enough context that the receiver can act without re-deriving intent. Four-section structure: SUMMARY / CURRENT / NEXT / LESSON.
**Rationale**: "Every round of 'wait, what were we doing?' burns a full context window and erodes trust."
**Violation indicator**: Handoff cards that read like logs instead of briefings.

## Rule 5: Channel Integrity
Telegram and LINE always route through the self-built lobster webhook (`plugins/telegram-lobster/`, `plugins/line-lobster/`). Never mount any official Telegram/LINE plugin. Supervisor scripts must not hardcode `--channels plugin:telegram@...` or equivalent.
**Rationale**: "Official plugin restarts auto-inject plugin flags, breaking webhook mode permanently."
**Violation indicator**: `claude-*.sh` supervisor containing `--channels plugin:` or a surprise `telegram@...` appearing in session flags after self-restart.

## Rule 6: Deletion With Confirmation
Before any destructive operation (rm, truncate, DROP, overwrite without backup), state the scope and count, then wait for confirmation. Ambiguous authorization ("要清嗎？") is a question, not a grant.
**Rationale**: "Neurodivergent user: irreversible actions without confirmation = high cognitive cost + trust damage."
**Violation indicator**: `rm -rf` or mass-overwrite executed on the same turn it was first mentioned.
