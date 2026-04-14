# External Config Patterns — Research Notes
> 2026-04-14, via Gemini CLI

## Key Structural Patterns Found

- **Progressive Disclosure / Three-Layer Split**: Power users keep `CLAUDE.md` at the root lean ("Critical Core" only), with path-scoped rules in `.claude/rules/*.md` loaded via YAML frontmatter, and full skill workflows in `.claude/skills/` that activate only on semantic trigger. This mirrors Life OS's `@include` injection pattern but makes the on-demand loading explicit via glob matching.

- **Identity vs. Behavior as separate documents**: The `~/.claude/CLAUDE.md` (global) holds persona/values/autonomy-level, while the repo-level `CLAUDE.md` is the "Instruction Manual." The split maps directly to how Life OS uses `soul.md` (identity) vs. `CLAUDE.local.md` (project behavior rules) — the pattern is independently validated.

- **`CLAUDE.md` as Index, not Manual**: High-performing configs treat `CLAUDE.md` as a Table of Contents using `@filename` syntax to pull in deeper docs. The AI "knows where to look" rather than having all knowledge pre-loaded. Heavy inline docs create token bloat and slow routing.

- **Capability section in root `CLAUDE.md`**: A short `## Capabilities` or `## Tools` block listing available slash commands and skills, with paths to implementation details. This acts as a session-start discovery mechanism — the AI reads one section, then pulls skill files on demand. No session hook required.

- **`description` field in skill files for semantic matching**: Skills are discovered via their description text, not hardcoded trigger lists. Claude matches user intent to the closest skill description. Life OS's `skill-routes.md` keyword table does this manually; the cleaner pattern is letting description-based matching do the work.

## Capability Discovery Patterns

- **MCP `/tools` list**: For large toolsets, developers expose capabilities dynamically through MCP servers. The AI calls the server's `/tools` endpoint at session start and gets a live inventory. This is what `qmd-search` already does for vault queries — the pattern generalizes to any plugin.

- **Hierarchical `capabilities.md`**: A flat but organized inventory (by domain: Content, Daily, Home, System) that Claude loads once per session. It answers "what can I do?" without embedding implementation details. This is the document Life OS's `.claude/capabilities.md` is being built toward.

- **Session hooks for stateful discovery**: `session-start.sh` pattern forces a memory sync into context at session start. Used alongside a capabilities manifest, this gives the AI both "what I can do" and "where I left off" in one load sequence.

- **Red-line protection as discovery guardrail**: Explicitly forbidding sub-agents from writing to `soul.md` / `CLAUDE.md` prevents capability-definition corruption. This is already in Life OS's `CLAUDE.local.md` and is confirmed as industry best practice for multi-agent setups.

- **`ROUTING.md` / Decision Matrix**: A separate doc that tells the AI which model or agent is best for a given task type (e.g., "use Gemini for one-shot summaries, Claude for complex refactors"). Keeps routing logic out of `soul.md` and out of `CLAUDE.md`.

## Recommendations for Life OS

- **Promote `capabilities.md` to a first-class session-start document**: Currently `.claude/capabilities.md` exists but may not be explicitly loaded at session start. It should be `@include`-ed in `CLAUDE.local.md` or read at the top of every session via the session hook, at the same level as `handoff.md`. This solves the "AI doesn't know what skills it has" problem without touching `soul.md`.

- **Collapse `skill-routes.md` keyword triggers into skill `SKILL.md` descriptions**: The current manual keyword table in `skill-routes.md` duplicates what good skill descriptions can do automatically. Consider moving trigger keywords directly into each `SKILL.md`'s frontmatter (e.g., `triggers: ["youtube", "youtu.be"]`) so the routing table becomes auto-generated rather than hand-maintained. The current table is a liability — it goes stale when skills change.

- **Formalize the Identity / Behavior / Capability three-layer boundary**: Life OS already has the three layers (soul.md / CLAUDE.local.md / skill-routes.md + capabilities.md) but they aren't named or documented as a pattern. Naming the boundary explicitly in `CLAUDE.local.md`'s header comment would prevent future authors (and future Claude sessions) from putting identity content in behavior files or vice versa. This is the single highest-leverage structural improvement from the external research.
