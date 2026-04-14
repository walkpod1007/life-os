<!-- Reference: https://github.com/dianyike/claude-code-insights -->

# Pragmatism (Risk-Based Flexibility)

- **Critical**: Maximum strictness for session supervisors (`scripts/claude-*.sh`), webhook processes (`plugins/*-lobster/`), channel routing, and core config files (`soul.md`, `~/.claude/CLAUDE.md`, `CLAUDE.local.md`, `MEMORY.md`, `STATE.md`, `flag.md`). No silent edits, no experimental changes, always verify after.
- **Standard**: Full enforcement with documented exceptions for skill routing (`skill-routes.md`), daily logs (`daily/`), vault captures, and cron-driven pipelines. Deviations get a TECH-DEBT comment.
- **Exploratory**: Relaxed testing requirements for new skill prototypes under `skills/*/`, experimental scripts in `drafts/`, and one-off capture spikes. Graduate to Standard before wiring into cron or channel flow.

## Priority Resolution

1. Security & Safety — core file protection, no secret leakage, no destructive ops without confirmation
2. User Intent — what the user actually asked for, including the unspoken "stop developing, start using"
3. Correctness — the change does what it claims; verification before completion claim
4. Code Quality — readability, shared libraries, no duplicate pipelines
5. Coverage/Metrics — nice to have, never the reason to block a working fix

## Tracking Deviations

When bending a rule deliberately, leave a trail:

```
<!-- TECH-DEBT: rule=<rule-name>, reason=<why>, owner=<session-or-date> -->
```

Examples of acceptable deviation: relaxing Rule 2 for a known-offline local script; skipping Rule 3's strict scope for a handoff cleanup explicitly authorized by the user.

Deviations without a TECH-DEBT marker count as violations, not judgment calls.
