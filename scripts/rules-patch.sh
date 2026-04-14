#!/bin/bash
# rules-patch.sh
# Nightly: scan solidified pitfall atom cards → patch into soul-behaviors.md
# Runs after skill-patch.sh (04:45). Called by cron at 05:00.
#
# Routing: solidified pitfall card → soul-behaviors.md category section
# Unlike skill-patch.sh (GOTCHAS.md), this writes to the behavior rule index.
# rules/ files (golden-rules, workflow, security) are NOT auto-updated here
# — those are policy documents and require human review.

set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# ── paths ──────────────────────────────────────────────────────────────
LIFEOS="$HOME/Documents/Life-OS"
SOUL_BEHAVIORS="$LIFEOS/soul-behaviors.md"
SOUL_BEHAVIORS_BAK="${SOUL_BEHAVIORS}.bak"
VAULT="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault"
PITFALL_DIR="$VAULT/80_apu/atoms/apu/pitfall"
LOG_FILE="$LIFEOS/scripts/pipeline.log"
PATCHED=0
SKIPPED=0

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [rules-patch] $*" >> "$LOG_FILE"
}

log "=== rules-patch 開始 ==="

# ── validate soul-behaviors.md exists ─────────────────────────────────
if [[ ! -f "$SOUL_BEHAVIORS" ]]; then
    log "soul-behaviors.md 不存在: $SOUL_BEHAVIORS，結束"
    exit 1
fi

# ── scan solidified pitfall cards ─────────────────────────────────────
if [[ ! -d "$PITFALL_DIR" ]]; then
    log "pitfall 目錄不存在: $PITFALL_DIR，結束"
    exit 0
fi

shopt -s nullglob
CARDS=("$PITFALL_DIR"/*.md)
shopt -u nullglob

if [[ ${#CARDS[@]} -eq 0 ]]; then
    log "沒有 pitfall 卡片，結束"
    exit 0
fi

# ── category英文→中文對照表（CLAUDE.md 規格用英文，soul-behaviors.md 用中文）─
declare -A CAT_EN_TO_ZH=(
    ["dialogue"]="對話節奏"
    ["tools"]="工具使用"
    ["memory"]="記憶與脈絡"
    ["system"]="系統操作"
    ["channel"]="頻道行為"
    ["boundary"]="邊界保護"
    ["execution"]="執行判斷"
)

for card in "${CARDS[@]}"; do
    filename="$(basename "$card")"
    [[ "$filename" == "INDEX.md" ]] && continue
    [[ -f "$card" ]] || continue

    # ── parse frontmatter（含 category 欄位）─────────────────────────
    read -r card_solidified card_rules_patched card_category <<< "$(python3 -c "
import sys
lines = open(sys.argv[1], 'r').read().split('\n')
in_fm = False
fm = {}
for line in lines:
    if line.strip() == '---':
        if not in_fm:
            in_fm = True
            continue
        else:
            break
    if in_fm and ':' in line:
        key, val = line.split(':', 1)
        fm[key.strip()] = val.strip()
print(fm.get('solidified','false'), fm.get('rules_patched',''), fm.get('category',''))
" "$card" 2>/dev/null)"

    # ── filter: only solidified: true, not yet rules_patched ──────────
    if [[ "$card_solidified" != "true" ]]; then
        continue
    fi
    if [[ -n "$card_rules_patched" ]]; then
        continue
    fi

    # ── extract body ───────────────────────────────────────────────────
    BODY="$(python3 -c "
import sys
lines = open(sys.argv[1], 'r').read().split('\n')
in_fm = False; body_start = 0
for i, line in enumerate(lines):
    if line.strip() == '---':
        if not in_fm: in_fm = True; continue
        else: body_start = i + 1; break
body = [l.strip() for l in lines[body_start:] if l.strip() and not l.strip().startswith('## ')]
print(' '.join(body))
" "$card" 2>/dev/null)"

    if [[ -z "$BODY" ]]; then
        log "卡片無內容，跳過: $filename"
        continue
    fi

    # ── 快速路由：如果卡片有 category 欄位，直接映射跳過 Haiku ────────
    CATEGORY=""
    RULE_TEXT=""

    if [[ -n "$card_category" ]] && [[ -n "${CAT_EN_TO_ZH[$card_category]+_}" ]]; then
        CATEGORY="${CAT_EN_TO_ZH[$card_category]}"
        log "快速路由（category 欄位）: $filename → $CATEGORY"
        # 仍需 Haiku 生成規則文字（只跳過分類判斷）
        RULE_PROMPT="以下是一張已固化的 pitfall 卡片內容：

\"${BODY}\"

用一句繁體中文寫出規則（格式：**關鍵詞**：說明。觸發條件盡量包含在關鍵詞裡）

只回覆規則文字，不要加任何前綴或解釋。"
        RULE_TEXT="$(claude --print --model haiku "$RULE_PROMPT" 2>/dev/null | head -1)"
    else
        # ── fallback: Haiku 同時判斷 category 和規則文字 ──────────────
        PROMPT="以下是一張已固化的 pitfall 卡片內容：

\"${BODY}\"

請做兩件事：
1. 判斷這條規則屬於哪個類別（只能選以下之一）：對話節奏、工具使用、記憶與脈絡、系統操作、頻道行為、邊界保護、執行判斷
2. 用一句繁體中文寫出規則（格式：**關鍵詞**：說明。觸發條件盡量包含在關鍵詞裡）

回覆格式（嚴格兩行，沒有其他文字）：
CATEGORY: <類別>
RULE: <規則文字>"

        HAIKU_RESULT="$(claude --print --model haiku "$PROMPT" 2>/dev/null)"
        CATEGORY="$(echo "$HAIKU_RESULT" | grep '^CATEGORY:' | sed 's/^CATEGORY: *//')"
        RULE_TEXT="$(echo "$HAIKU_RESULT" | grep '^RULE:' | sed 's/^RULE: *//')"
    fi

    if [[ -z "$CATEGORY" ]] || [[ -z "$RULE_TEXT" ]]; then
        log "無法取得 category 或 rule text，跳過: $filename"
        continue
    fi

    # map category → soul-behaviors.md section header
    case "$CATEGORY" in
        "對話節奏")     SECTION_HEADER="## 對話節奏" ;;
        "工具使用")     SECTION_HEADER="## 工具使用" ;;
        "記憶與脈絡")   SECTION_HEADER="## 記憶與脈絡" ;;
        "系統操作")     SECTION_HEADER="## 系統操作" ;;
        "頻道行為")     SECTION_HEADER="## 頻道行為" ;;
        "邊界保護")     SECTION_HEADER="## 邊界保護" ;;
        "執行判斷")     SECTION_HEADER="## 執行判斷" ;;
        *)
            log "無效類別「${CATEGORY}」，跳過: $filename"
            continue
            ;;
    esac

    log "配對: $filename → ${CATEGORY}"

    # ── check semantic dedup against existing rules in that section ────
    EXISTING_RULES="$(python3 -c "
import sys
content = open(sys.argv[1]).read()
section = sys.argv[2]
lines = content.split('\n')
in_section = False
rules = []
for line in lines:
    if line.startswith('## '):
        if in_section:
            break
        if section in line:
            in_section = True
            continue
    if in_section and line.startswith('- '):
        rules.append(line.strip())
print('\n'.join(rules))
" "$SOUL_BEHAVIORS" "$SECTION_HEADER" 2>/dev/null)"

    DEDUP_ACTION="new"
    if [[ -n "$EXISTING_RULES" ]]; then
        DEDUP_PROMPT="新規則：
\"${RULE_TEXT}\"

現有規則列表：
${EXISTING_RULES}

這條新規則是否與某條現有規則描述同一件事？回覆 YES 或 NO，不要加解釋。"

        DEDUP="$(claude --print --model haiku "$DEDUP_PROMPT" 2>/dev/null)"
        if echo "$DEDUP" | grep -qi '^yes'; then
            DEDUP_ACTION="skip"
        fi
    fi

    if [[ "$DEDUP_ACTION" == "skip" ]]; then
        log "語意重複，跳過插入: $filename → ${CATEGORY}"
        SKIPPED=$((SKIPPED + 1))
    else
        # ── backup before write ────────────────────────────────────────
        cp "$SOUL_BEHAVIORS" "$SOUL_BEHAVIORS_BAK"

        # ── insert rule into the correct section ──────────────────────
        python3 -c "
import sys

soul_path = sys.argv[1]
section_keyword = sys.argv[2]
new_rule = sys.argv[3]

with open(soul_path, 'r') as f:
    content = f.read()

lines = content.split('\n')
new_lines = []
in_target_section = False
inserted = False

for i, line in enumerate(lines):
    new_lines.append(line)

    if not inserted and line.startswith('## '):
        if section_keyword.replace('## ','') in line:
            in_target_section = True
        else:
            if in_target_section:
                new_lines.insert(len(new_lines)-1, '- ' + new_rule)
                new_lines.insert(len(new_lines)-1, '')
                inserted = True
            in_target_section = False

    # Insert before the '---' separator that ends the section
    if in_target_section and not inserted and line.strip() == '---':
        new_lines.pop()
        new_lines.append('- ' + new_rule)
        new_lines.append('')
        new_lines.append('---')
        inserted = True
        in_target_section = False

# EOF fallback: still in target section (last section, ends with ---)
if not inserted and in_target_section:
    while new_lines and new_lines[-1].strip() == '':
        new_lines.pop()
    new_lines.append('')
    new_lines.append('- ' + new_rule)
    inserted = True

if not inserted:
    new_lines.append('')
    new_lines.append('- ' + new_rule)

with open(soul_path, 'w') as f:
    f.write('\n'.join(new_lines))
" "$SOUL_BEHAVIORS" "$SECTION_HEADER" "$RULE_TEXT"
        log "插入新規則到 ${CATEGORY}: $filename"
        PATCHED=$((PATCHED + 1))
    fi

    # ── mark card as rules_patched（skip 也要標，避免明天重複判斷）────
    python3 -c "
import sys
path = sys.argv[1]
category = sys.argv[2]
with open(path, 'r') as f:
    content = f.read()
lines = content.split('\n')
new_lines = []
in_fm = False
inserted = False
for line in lines:
    if line.strip() == '---':
        if not in_fm:
            in_fm = True
            new_lines.append(line)
            continue
        else:
            if not inserted:
                new_lines.append(f'rules_patched: {category}')
                inserted = True
            in_fm = False
            new_lines.append(line)
            continue
    new_lines.append(line)
with open(path, 'w') as f:
    f.write('\n'.join(new_lines))
" "$card" "$CATEGORY"

done

# ── git commit only when soul-behaviors.md was actually modified ────────
if [[ "$PATCHED" -gt 0 ]]; then
    cd "$LIFEOS"
    git add soul-behaviors.md
    git commit -m "auto: rules-patch — ${PATCHED} new rules, ${SKIPPED} dedup-skipped → soul-behaviors.md"
    log "git commit 完成: ${PATCHED} 新增, ${SKIPPED} 重複跳過"
    rm -f "$SOUL_BEHAVIORS_BAK"
elif [[ "$SKIPPED" -gt 0 ]]; then
    log "本次 ${SKIPPED} 張卡片已標記（語意重複，soul-behaviors.md 無變更）"
    rm -f "$SOUL_BEHAVIORS_BAK"
else
    log "本次無卡片需要 patch"
fi

log "=== rules-patch 結束 (patched: ${PATCHED}, skipped: ${SKIPPED}) ==="

# ── regenerate pitfall-digest.md ──────────────────────────────────────
DIGEST_OUT="$HOME/.claude/pitfall-digest.md"

python3 - "$PITFALL_DIR" "$DIGEST_OUT" <<'PYEOF'
import sys, os, re
from collections import defaultdict

pitfall_dir = sys.argv[1]
output_path = sys.argv[2]

CAT_ORDER = ["對話節奏", "工具使用", "記憶與脈絡", "系統操作", "頻道行為", "邊界保護", "執行判斷", "其他"]
CAT_EN = {"dialogue":"對話節奏","tools":"工具使用","memory":"記憶與脈絡",
          "system":"系統操作","channel":"頻道行為","boundary":"邊界保護","execution":"執行判斷"}

groups = defaultdict(list)

for fname in sorted(os.listdir(pitfall_dir)):
    if not fname.endswith('.md') or fname == 'INDEX.md':
        continue
    path = os.path.join(pitfall_dir, fname)
    with open(path, 'r') as f:
        content = f.read()

    lines = content.split('\n')
    in_fm = False
    fm = {}
    body_start = 0
    for i, line in enumerate(lines):
        if line.strip() == '---':
            if not in_fm:
                in_fm = True
                continue
            else:
                body_start = i + 1
                break
        if in_fm and ':' in line:
            k, v = line.split(':', 1)
            fm[k.strip()] = v.strip()

    if fm.get('solidified', 'false') != 'true':
        continue

    # extract first meaningful sentence of body
    body_lines = [l.strip() for l in lines[body_start:] if l.strip() and not l.strip().startswith('## ')]
    if not body_lines:
        continue
    first_line = body_lines[0]
    # truncate at first sentence end or 80 chars
    sentence = re.split(r'[。\.！!；;]', first_line)[0].strip()
    if len(sentence) > 80:
        sentence = sentence[:77] + '...'
    if not sentence:
        continue

    # determine category
    cat_en = fm.get('category', '')
    cat_zh = CAT_EN.get(cat_en, fm.get('rules_patched', '其他') or '其他')
    if cat_zh not in CAT_ORDER:
        cat_zh = '其他'

    groups[cat_zh].append(sentence)

# write digest
lines_out = [
    "# pitfall-digest — 固化踩坑速查",
    f"> 自動生成 by rules-patch.sh。只含 solidified: true 的卡片。共 {sum(len(v) for v in groups.values())} 條。",
    ""
]
for cat in CAT_ORDER:
    if cat not in groups:
        continue
    lines_out.append(f"## {cat}")
    for rule in groups[cat]:
        lines_out.append(f"- {rule}")
    lines_out.append("")

with open(output_path, 'w') as f:
    f.write('\n'.join(lines_out))

print(f"digest: {sum(len(v) for v in groups.values())} rules → {output_path}")
PYEOF

log "pitfall-digest.md 更新完成"
