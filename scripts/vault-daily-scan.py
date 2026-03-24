#!/usr/bin/env python3
"""
vault-daily-scan.py
每日批次掃描：一次處理一個子資料夾，輪流跑完整個 Vault
- 用 scan-state.json 記錄進度，避免重複掃或一次掃太多
- 廢檔移到 _trash/（不直接刪）
- 輸出當日報告到 scripts/daily-scan-log/YYYY-MM-DD.md
"""

import os
import re
import json
import subprocess
import yaml
from pathlib import Path
from datetime import datetime

VAULT = Path("/Users/Modema11434/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault")
TRASH = Path("/Users/Modema11434/Desktop/vault-trash")
STATE_FILE = Path("/Users/Modema11434/Documents/Life-OS/scripts/scan-state.json")
LOG_DIR = Path("/Users/Modema11434/Documents/Life-OS/scripts/daily-scan-log")
LOG_DIR.mkdir(exist_ok=True)
TRASH.mkdir(exist_ok=True)

# 要輪掃的根資料夾清單（按順序排，每次取一個）
SCAN_ROOTS = [
    VAULT / "00_Inbox",    # 每次必跑第一個（新東西最多）
    VAULT / "09_Gems",
    VAULT / "10_Projects",
    VAULT / "20_Areas",
    VAULT / "30_Resources",
    VAULT / "40_Archive",
    VAULT / "50_Research",
]

SKIP_NAMES = {"INDEX.md", "_MOC.md", "_index.md", "README.md", "VAULT-GUIDE.md"}
SKIP_DIRS = {".smart-env", "_trash", ".obsidian"}

# ---------- 狀態管理 ----------

def load_state():
    if STATE_FILE.exists():
        return json.loads(STATE_FILE.read_text())
    return {"last_root_index": -1, "last_scanned_folders": []}

def save_state(state):
    STATE_FILE.write_text(json.dumps(state, ensure_ascii=False, indent=2))

def pick_next_batch(state):
    """選下一個要掃的子資料夾清單（一個 root 下的所有直屬子資料夾）"""
    next_idx = (state.get("last_root_index", -1) + 1) % len(SCAN_ROOTS)
    root = SCAN_ROOTS[next_idx]
    if not root.exists():
        return next_idx, root, []
    # 收集該 root 下的直屬子資料夾 + 根目錄散落檔案
    folders = [root]  # 包含根目錄本身（處理散落的 .md）
    for d in sorted(root.iterdir()):
        if d.is_dir() and d.name not in SKIP_DIRS:
            folders.append(d)
    return next_idx, root, folders

# ---------- 廢檔判斷 ----------

def get_real_lines(text):
    if text.startswith("---"):
        end = text.find("---", 3)
        if end != -1:
            text = text[end+3:]
    lines = [l.strip() for l in text.splitlines()]
    return [l for l in lines if l and not l.startswith("#") and not l.startswith(">") and not l.startswith("---")]

def is_empty_index(name, text):
    if name != "INDEX.md":
        return False
    rows = [l for l in text.splitlines() if l.strip().startswith("|") and not re.match(r"^\|[-| ]+\|$", l.strip())]
    return len(rows) <= 2

def scan_folder(folder):
    """掃單一資料夾（非遞迴），分類廢檔 / 疑似廢檔 / 保留"""
    waste, suspect, keep = [], [], []
    if not folder.exists():
        return waste, suspect, keep

    for md in sorted(folder.glob("*.md")):
        if any(d in str(md) for d in SKIP_DIRS):
            continue
        if md.name in SKIP_NAMES:
            continue
        try:
            text = md.read_text(encoding="utf-8", errors="ignore")
        except:
            continue

        lines = len(text.splitlines())
        real = get_real_lines(text)

        if is_empty_index(md.name, text):
            waste.append((md, "空白 INDEX"))
            continue
        if lines <= 8 and len(real) <= 1:
            waste.append((md, f"空殼（{lines} 行）"))
            continue
        if lines <= 30 and len(real) <= 5:
            suspect.append((md, text[:500]))
            continue
        keep.append(md)

    return waste, suspect, keep

def gemini_judge(suspects):
    if not suspects:
        return {}
    items = [f"[{i+1}] 檔名：{p.name}\n{c[:300]}\n" for i, (p, c) in enumerate(suspects)]
    prompt = ("你是 Obsidian 整理助手。逐一判斷以下 markdown 是否為廢檔（空殼/無實質內容/placeholder）。\n"
              "格式：[編號] WASTE 或 KEEP : 理由\n---\n" + "\n".join(items))
    try:
        r = subprocess.run(["gemini"], input=prompt, capture_output=True, text=True, timeout=90)
        verdicts = {}
        for line in r.stdout.splitlines():
            m = re.match(r"\[(\d+)\]\s+(WASTE|KEEP)", line.strip(), re.I)
            if m:
                idx = int(m.group(1)) - 1
                reason = line[m.end():].strip().lstrip(":").strip()
                verdicts[idx] = (m.group(2).upper(), reason)
        return verdicts
    except:
        return {}

def move_to_trash(path, reason):
    dest = TRASH / (str(path.relative_to(VAULT)).replace("/", "_"))
    path.rename(dest)
    return dest

# ---------- 主流程 ----------

def main():
    today = datetime.now().strftime("%Y-%m-%d")
    log_path = LOG_DIR / f"{today}.md"
    state = load_state()
    next_idx, root, folders = pick_next_batch(state)

    log = [f"# Vault 日掃報告 — {today}", f"", f"掃描資料夾：`{root.name}`（{len(folders)} 個子目錄）", ""]

    total_waste = 0
    total_suspect_waste = 0

    for folder in folders:
        waste, suspect, keep = scan_folder(folder)
        verdicts = gemini_judge(suspect)

        # 處理確定廢檔
        for path, reason in waste:
            move_to_trash(path, reason)
            log.append(f"- ❌ `{path.relative_to(VAULT)}` — {reason}")
            total_waste += 1

        # 處理 Gemini 判定
        for i, (path, _) in enumerate(suspect):
            v, r = verdicts.get(i, ("KEEP", "未判定"))
            if v == "WASTE":
                move_to_trash(path, r)
                log.append(f"- ⚠️ `{path.relative_to(VAULT)}` — {r}")
                total_suspect_waste += 1

    log += ["", "---", f"移到 _trash：{total_waste + total_suspect_waste} 個", ""]

    log_path.write_text("\n".join(log), encoding="utf-8")
    print("\n".join(log))

    # 更新狀態
    state["last_root_index"] = next_idx
    save_state(state)
    print(f"\n狀態已更新，下次從 index {(next_idx+1) % len(SCAN_ROOTS)} 開始")

if __name__ == "__main__":
    main()
