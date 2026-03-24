#!/usr/bin/env python3
"""
vault-inbox-process.py
處理 00_Inbox 的散落檔案：
1. 去日期前綴（重命名）
2. 重構標題（優化可讀性）
3. 確保 Frontmatter 完整
4. 加上 5 個雙向連結（掃 Vault tag 匹配）
"""

import os
import re
import yaml
import glob
from pathlib import Path
from datetime import datetime

VAULT = Path("/Users/Modema11434/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault")
INBOX = VAULT / "00_Inbox"
SKIP_FILES = {"INDEX.md", "README.md", "_index.md", "📌_Quick_Refs.md", "📥_Inbox.md", "🤖_AI_Tasks.md", "VAULT-GUIDE.md"}

def parse_frontmatter(content):
    """解析 YAML frontmatter，回傳 (meta_dict, body_str)"""
    if content.startswith("---"):
        end = content.find("---", 3)
        if end != -1:
            yaml_str = content[3:end].strip()
            body = content[end+3:].strip()
            try:
                meta = yaml.safe_load(yaml_str) or {}
                return meta, body
            except:
                pass
    return {}, content

def build_frontmatter(meta):
    """把 dict 轉回 YAML frontmatter block"""
    return "---\n" + yaml.dump(meta, allow_unicode=True, default_flow_style=False, sort_keys=False).strip() + "\n---\n\n"

def strip_date_from_filename(name):
    """移除 YYYY-MM-DD- 前綴"""
    return re.sub(r"^\d{4}-\d{2}-\d{2}-?", "", name)

def clean_title(filename_stem):
    """把檔名 stem 轉成可讀標題"""
    title = filename_stem.replace("-", " ").replace("_", " ")
    return title.strip()

def find_related_files(meta, body, exclude_path, limit=5):
    """根據 tags 在 Vault 掃描相關檔案，回傳 [[wikilink]] 清單"""
    tags = meta.get("tags", [])
    if isinstance(tags, str):
        tags = [tags]

    keywords = set()
    for t in tags:
        keywords.update(str(t).lower().split())

    # 從 body 取前 500 字的關鍵詞補充
    words = re.findall(r'[\w\u4e00-\u9fff]+', body[:500])
    freq = {}
    for w in words:
        if len(w) > 3:
            freq[w] = freq.get(w, 0) + 1
    top_words = {k for k, v in sorted(freq.items(), key=lambda x: -x[1])[:10]}
    keywords.update(top_words)

    candidates = []
    for md_file in VAULT.rglob("*.md"):
        if md_file == exclude_path:
            continue
        if ".smart-env" in str(md_file) or "_trash" in str(md_file).lower():
            continue
        if md_file.name in SKIP_FILES:
            continue

        try:
            text = md_file.read_text(encoding="utf-8", errors="ignore")[:1000]
            score = 0
            for kw in keywords:
                if kw.lower() in text.lower():
                    score += 1
            if score >= 2:
                candidates.append((score, md_file))
        except:
            continue

    candidates.sort(key=lambda x: -x[0])
    results = []
    seen_stems = set()
    for score, f in candidates[:limit*2]:
        stem = f.stem
        if stem not in seen_stems:
            seen_stems.add(stem)
            results.append(f"[[{stem}]]")
        if len(results) >= limit:
            break
    return results

def process_file(file_path: Path):
    """處理單一檔案"""
    original_name = file_path.name
    stem = file_path.stem

    # 1. 去日期重命名
    new_stem = strip_date_from_filename(stem)
    new_name = new_stem + ".md"
    new_path = file_path.parent / new_name

    # 2. 讀內容
    content = file_path.read_text(encoding="utf-8")
    meta, body = parse_frontmatter(content)

    # 3. 補全 frontmatter
    if "title" not in meta:
        meta["title"] = clean_title(new_stem)
    if "processed" not in meta:
        meta["processed"] = datetime.now().strftime("%Y-%m-%d")
    if "status" not in meta:
        meta["status"] = "processed"
    else:
        meta["status"] = "processed"

    # 4. 找雙向連結
    related = find_related_files(meta, body, file_path)

    # 5. 加入相關連結區塊（如果還沒有）
    if related and "## 相關連結" not in body:
        links_section = "\n\n---\n\n## 相關連結\n\n" + "\n".join(f"- {r}" for r in related) + "\n"
        body = body + links_section

    # 6. 寫回新檔案
    new_content = build_frontmatter(meta) + body
    new_path.write_text(new_content, encoding="utf-8")

    # 7. 如果改名，刪舊檔
    if file_path != new_path:
        file_path.unlink()

    return original_name, new_name, related

def main():
    targets = []

    # 根目錄直接散落的
    for f in INBOX.glob("*.md"):
        if f.name not in SKIP_FILES:
            targets.append(f)

    # 📌_Quick_Refs 子目錄
    quick_refs = INBOX / "📌_Quick_Refs"
    if quick_refs.exists():
        for f in quick_refs.glob("*.md"):
            if f.name not in SKIP_FILES:
                targets.append(f)

    if not targets:
        print("沒有找到需要處理的檔案")
        return

    print(f"找到 {len(targets)} 個待處理檔案\n")

    for f in targets:
        old_name, new_name, links = process_file(f)
        renamed = f"→ {new_name}" if old_name != new_name else "（名稱不變）"
        print(f"✅ {old_name}")
        print(f"   {renamed}")
        print(f"   雙向連結：{', '.join(links) if links else '無'}")
        print()

if __name__ == "__main__":
    main()
