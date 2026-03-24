#!/usr/bin/env python3
"""
build-skills-json.py — 掃 skills/ 目錄，產出 skills.json 供 Skill Store 前端讀取
用法：python3 build-skills-json.py
輸出：skill-store/skills.json
"""
import json, os, re
from pathlib import Path

SKILLS_DIR = Path(__file__).parent.parent / "skills"
OUTPUT = Path(__file__).parent / "skills.json"

CATEGORY_MAP = {
    'morning-brief': 'daily', 'daily-log': 'daily', 'daily-review': 'daily',
    'life-os-checklist': 'daily', 'heartbeat-checkin': 'daily',
    'youtube-grabber': 'content', 'podcast-grabber': 'content',
    'capture': 'content', 'content-digest': 'content',
    'notebooklm-query': 'knowledge', 'notebooklm-save': 'knowledge',
    'insight': 'review', 'week-push': 'review',
    'sonoscli': 'home', 'smart-home': 'home', 'samsung-smartthings': 'home',
    'samsung-frame-art': 'home', 'roborock': 'home',
    'xiaomi-home': 'home', 'openhue': 'home',
    'social-monitor': 'social',
    'pipeline': 'pipeline', 'loop-manager': 'pipeline',
    'telegram-handler': 'system', 'skill-optimizer': 'system',
    'triad-tools': 'system', 'gcal-check': 'system',
    'gmail-triage': 'system', 'obsidian-capture': 'system',
    'imagen-gen': 'image',
}

def parse_frontmatter(text):
    """Extract YAML frontmatter between --- markers. Handles multiline | values."""
    m = re.match(r'^---\s*\n(.*?)\n---', text, re.DOTALL)
    if not m:
        return {}
    fm = {}
    lines = m.group(1).splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        if ':' in line:
            k, _, v = line.partition(':')
            k = k.strip()
            v = v.strip()
            if v == '|':
                # multiline: collect next indented line(s)
                parts = []
                i += 1
                while i < len(lines) and (lines[i].startswith(' ') or lines[i].startswith('\t')):
                    parts.append(lines[i].strip())
                    i += 1
                fm[k] = ' '.join(parts)
                continue
            else:
                fm[k] = v
        i += 1
    return fm

def build():
    skills = []
    for skill_dir in sorted(SKILLS_DIR.iterdir()):
        skill_md = skill_dir / "SKILL.md"
        if not skill_md.exists():
            continue

        text = skill_md.read_text(encoding='utf-8')
        fm = parse_frontmatter(text)
        name = fm.get('name') or skill_dir.name

        # icon: 優先用 icon.png，沒有就空
        icon_path = skill_dir / "icon.png"
        icon = f"../skills/{skill_dir.name}/icon.png" if icon_path.exists() else None

        # triggers: 從 frontmatter 或 description 取
        triggers_raw = fm.get('triggers', '')
        triggers = [t.strip().strip('"').strip("'") for t in triggers_raw.split(',') if t.strip()] if triggers_raw else []

        # 描述截短：取第一句（遇到句號/。/\n 截斷），最多 60 字
        raw_desc = fm.get('description', '')
        for sep in ['。', '.', '，觸發', '。觸發', '\n']:
            if sep in raw_desc:
                raw_desc = raw_desc.split(sep)[0].strip()
                break
        short_desc = raw_desc[:60].strip()

        skills.append({
            "name": name,
            "description": short_desc,
            "version": fm.get('version', '1.0.0'),
            "category": CATEGORY_MAP.get(name, 'system'),
            "icon": icon,
            "triggers": triggers,
            "installed": True,
        })

    OUTPUT.write_text(json.dumps(skills, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f"✅ 產出 {len(skills)} 個技能 → {OUTPUT}")
    return skills

if __name__ == "__main__":
    build()
