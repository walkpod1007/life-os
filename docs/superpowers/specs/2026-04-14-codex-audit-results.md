# Codex Audit Results
> 2026-04-14

## soul.md Contradictions Found

Analysis of `/Users/applyao/Documents/life-os/soul.md` lines 99–132 (阿普踩坑 — 對話行為 section).

**Conflict 1: "直接改不要問" vs "先建議再執行" (lines 101 and 107)**

Line 101 rule: If a fix is unambiguous, in-scope, and reversible — do it directly without asking. The example given specifically criticizes the "要改嗎？" → "要" confirmation loop as token waste and cognitive load.

Line 107 rule: "先建議再執行" — for destructive operations where authorization is unclear, say "我打算做 X" before acting.

Ambiguity: There is no crisp boundary between "明確且可逆" (line 101 threshold) and "不確定是否有授權的破壞性操作" (line 107 threshold). Both rules apply to modifications, and the judgment call about which bucket an action falls into is left entirely to Claude. A file deletion that has a clear fix path could be argued either way. The rules don't define what counts as "destructive" vs "reversible" for borderline cases (e.g., overwriting a config file).

**Conflict 2: "用戶給權限就做完" vs "先建議再執行" (lines 118 and 107)**

Line 118: Once the user grants a token or authorization, Claude executes all intermediate steps to completion — never hands mid-task steps back to the user.

Line 107: Before uncertain-authorization destructive operations, announce intent and wait.

Ambiguity: When a user says "幫我重設這個服務" and provides credentials, it's unclear whether the "authorization" covers all destructive sub-steps (e.g., wiping config, stopping the process). Line 118 says finish it; line 107 says pause for uncertain-authorization actions. No tiebreaker rule exists.

**Conflict 3: "不要問搜尋用途" vs "整段話看完才做判斷" (lines 102 and 104)**

Line 102: When user says "搜尋 XXX", search immediately — don't ask "用途是什麼".

Line 104: Voice input often trails off mid-sentence ("一個…一個…"). Wait for the full semantic unit before interpreting; slow 2 seconds is fine.

Ambiguity: These conflict on ambiguous search requests. If user says "搜一下 Apple…" and trails off, line 102 says act immediately while line 104 says wait for the full utterance. No rule specifies which takes precedence when the trigger phrase is present but the object is incomplete.

**Conflict 4: "修復後立刻補跑驗證" vs "任務用子代理執行，主 session 不被佔用" (lines 105 and 108)**

Line 105: After any repair, immediately run a manual verification pass in the same turn — don't wait for the cron schedule.

Line 108: All tasks should be delegated to an Agent; keep the main session free; sub-agents use Haiku by default.

Ambiguity: Verification runs (e.g., `bash script.sh` to confirm a fix) are short one-liners that don't obviously warrant spawning an Agent, but line 108's "盡量開 Agent" creates friction. No threshold (complexity, duration, model tier) is defined for when a verification step should go sub-agent vs run inline.

**Conflict 5: Sonos volume rule formatting issue (line 130)**

Line 130 contains two rules concatenated without a list separator: "書房預設音量" and "capture 初始回覆文案" are merged on the same bullet. The line reads: `每次播放 Sonos 書房前先執行 ... - **capture 回覆文案**：...` — the second rule's leading `-` dash is swallowed into the preceding sentence. This is a formatting defect that could cause the `capture` rule to be missed on a partial read.

---

## Skill Routing Gaps

### Installed but no route (in `skills/` directory, not referenced in skill-routes.md):

None. All 61 skill directories have at least one entry in skill-routes.md (either as a primary trigger or in the passive/system tables).

### Routed but not installed (referenced in skill-routes.md, no matching `skills/` directory):

- **`frontend`** — Referenced in skill-routes.md as `plugins/frontend/recipes/` (plugin, not a skill). Directory exists at `plugins/frontend/`, not under `skills/`. The route entry type is "plugin" which is correct, but the `skills/` scan misses it. Not a true gap — it's intentionally a plugin.
- **`ralph-loop`** — Referenced in skill-routes.md as type "remote / RemoteTrigger". No `skills/ralph-loop/` directory exists. This appears to be a RemoteTrigger endpoint, not a file-based skill, so the absence of a `skills/` directory is expected — but there is no documentation anywhere in the repo about what `ralph-loop` is, how to invoke it, or its current status (live vs planned).

### Summary note:
The `frontend` gap is benign (plugin vs skill classification). The `ralph-loop` gap is a potential documentation debt — it's listed as a user-facing trigger ("跑到完成") with no backing documentation, SKILL.md, or visible RemoteTrigger definition in the repo.

---

## MEMORY.md Status

Grep count for "handoff" or "交接" in MEMORY.md: **0**

The MEMORY.md file contains no zombie handoff entries — all references are properly cleaned up. Status is as expected.
