#!/usr/bin/env python3
"""
vault-waste-detect.py
1. 掃描 30_Resources 所有 .md
2. 自動標記明確廢檔（空 INDEX、空殼）
3. 收集疑似廢檔，批次送 Gemini CLI 判斷
4. 輸出報告
"""

import os
import re
import subprocess
import json
from pathlib import Path

VAULT = Path("/Users/Modema11434/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault")
TARGET = VAULT / "30_Resources"
TRASH = Path("/Users/Modema11434/Desktop/vault-trash")
REPORT_PATH = Path("/Users/Modema11434/Documents/Life-OS/scripts/waste-report.md")

AUTO_SKIP = {"INDEX.md", "_MOC.md", "_index.md", "README.md", "_MOC.md"}

def get_real_content_lines(text):
    """去除 frontmatter、標題、空行後的實際內容行數"""
    # 去 frontmatter
    if text.startswith("---"):
        end = text.find("---", 3)
        if end != -1:
            text = text[end+3:]
    lines = [l.strip() for l in text.splitlines()]
    real = [l for l in lines if l and not l.startswith("#") and not l.startswith(">") and not l.startswith("---")]
    return len(real), real

def is_auto_index(name, text):
    """INDEX.md 且表格無資料"""
    if name != "INDEX.md":
        return False
    # 找表格行（|開頭，非分隔行）
    rows = [l for l in text.splitlines() if l.strip().startswith("|") and not re.match(r"^\|[-| ]+\|$", l.strip())]
    return len(rows) <= 2  # 只有 header，沒資料

def scan_files():
    waste = []    # 確定廢檔
    suspect = []  # 疑似廢檔，送 Gemini
    keep = []     # 明顯有內容

    for md in TARGET.rglob("*.md"):
        if ".smart-env" in str(md) or "_trash" in str(md).lower():
            continue

        name = md.name
        try:
            text = md.read_text(encoding="utf-8", errors="ignore")
        except:
            continue

        lines = len(text.splitlines())
        real_count, real_lines = get_real_content_lines(text)

        # 自動廢檔判定
        if is_auto_index(name, text):
            waste.append((md, "空白 INDEX（表格無資料）"))
            continue

        if name in AUTO_SKIP:
            continue

        # 超短且無內容
        if lines <= 8 and real_count <= 1:
            waste.append((md, f"空殼（{lines} 行，實質內容 {real_count} 行）"))
            continue

        # 疑似（9-30 行，實質內容少）
        if lines <= 30 and real_count <= 5:
            suspect.append((md, text[:800]))
            continue

        keep.append(md)

    return waste, suspect, keep

def gemini_batch_judge(suspects):
    """把所有疑似檔案打包成一個 prompt 送 Gemini，要求逐條判斷"""
    if not suspects:
        return {}

    items = []
    for i, (path, content) in enumerate(suspects):
        items.append(f"[{i+1}] 檔名：{path.name}\n內容：\n{content[:400]}\n")

    prompt = """你是 Obsidian Vault 整理助手。以下有多個 markdown 檔案需要你逐一判斷是否為廢檔。

廢檔定義：空殼、無實質內容、只有標題沒有正文、自動生成但無資料、已被更好的檔案取代。

請對每個檔案回答，格式嚴格如下（一行一個）：
[編號] WASTE 或 KEEP : 理由（一行內）

---
""" + "\n\n".join(items)

    try:
        result = subprocess.run(
            ["gemini"],
            input=prompt,
            capture_output=True,
            text=True,
            timeout=120
        )
        output = result.stdout.strip()
    except Exception as e:
        print(f"Gemini 呼叫失敗：{e}")
        return {}

    # 解析結果
    verdicts = {}
    for line in output.splitlines():
        m = re.match(r"\[(\d+)\]\s+(WASTE|KEEP)", line.strip(), re.IGNORECASE)
        if m:
            idx = int(m.group(1)) - 1
            verdict = m.group(2).upper()
            reason = line[m.end():].strip().lstrip(":").strip()
            verdicts[idx] = (verdict, reason)
    return verdicts

def write_report(waste, suspect_results, keep_count):
    lines = []
    lines.append("# Vault 廢檔偵測報告 — 30_Resources")
    lines.append(f"\n生成時間：{__import__('datetime').datetime.now().strftime('%Y-%m-%d %H:%M')}")
    lines.append(f"\n掃描總數：{len(waste) + len(suspect_results) + keep_count} 個 .md 檔\n")

    lines.append("---\n")
    lines.append(f"## ❌ 確定廢檔（{len(waste)} 個）\n")
    for path, reason in waste:
        rel = path.relative_to(VAULT)
        lines.append(f"- `{rel}` — {reason}")

    gemini_waste = [(i, path, v, r) for i, path, v, r in suspect_results if v == "WASTE"]
    gemini_keep = [(i, path, v, r) for i, path, v, r in suspect_results if v == "KEEP"]

    lines.append(f"\n## ⚠️ Gemini 判定廢檔（{len(gemini_waste)} 個）\n")
    for _, path, _, reason in gemini_waste:
        rel = path.relative_to(VAULT)
        lines.append(f"- `{rel}` — {reason}")

    lines.append(f"\n## ✅ Gemini 判定保留（{len(gemini_keep)} 個）\n")
    for _, path, _, reason in gemini_keep:
        rel = path.relative_to(VAULT)
        lines.append(f"- `{rel}` — {reason}")

    lines.append(f"\n---\n\n**建議刪除：{len(waste) + len(gemini_waste)} 個**")
    REPORT_PATH.write_text("\n".join(lines), encoding="utf-8")

def main():
    print("掃描中...")
    waste, suspect, keep = scan_files()
    print(f"確定廢檔：{len(waste)}")
    print(f"疑似廢檔（送 Gemini）：{len(suspect)}")
    print(f"明顯保留：{len(keep)}")

    print(f"\nGemini 批次判斷 {len(suspect)} 個疑似檔案...")
    verdicts = gemini_batch_judge(suspect)

    suspect_results = []
    for i, (path, _) in enumerate(suspect):
        v, r = verdicts.get(i, ("KEEP", "Gemini 未判斷，預設保留"))
        suspect_results.append((i, path, v, r))
        print(f"  [{i+1}] {path.name} → {v}")

    write_report(waste, suspect_results, len(keep))
    print(f"\n報告已輸出：{REPORT_PATH}")

    total_waste = len(waste) + sum(1 for _, _, v, _ in suspect_results if v == "WASTE")
    print(f"建議刪除總計：{total_waste} 個")

if __name__ == "__main__":
    main()
