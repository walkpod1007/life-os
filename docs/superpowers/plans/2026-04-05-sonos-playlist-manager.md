# Sonos Playlist Manager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add list / save / play commands for Sonos-native playlists, triggerable from Telegram natural language.

**Architecture:** A Python script (`playlist-manager.py`) handles soco calls; a bash wrapper (`playlist-manager.sh`) is the entry point Claude calls. SKILL.md and CLAUDE.local.md are updated with trigger keywords and response formats.

**Tech Stack:** Python 3, soco 0.30.x (already installed), bash

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `scripts/playlist-manager.py` | Create | soco logic: list / save / play |
| `scripts/playlist-manager.sh` | Create | bash wrapper, argument parsing |
| `skills/sonoscli/SKILL.md` | Modify | add playlist section with triggers + LINE format |
| `CLAUDE.local.md` | Modify | add 3 routing rules |

---

## Task 1: Create `playlist-manager.py`

**Files:**
- Create: `scripts/playlist-manager.py`

- [ ] **Step 1: Verify soco discover works from script context**

```bash
python3 -c "
import soco
speakers = list(soco.discover() or [])
print([s.player_name for s in speakers])
"
```
Expected: `['書房', ...]` — at least one speaker listed.

- [ ] **Step 2: Write playlist-manager.py**

```python
#!/usr/bin/env python3
"""Sonos playlist manager — list / save / play"""
import sys
import soco

DEFAULT_ROOM = "書房"

def get_speaker(name: str):
    speakers = list(soco.discover() or [])
    if not speakers:
        print("ERROR: 找不到 Sonos 音響，請確認 Local Network 權限已開啟")
        sys.exit(1)
    for s in speakers:
        if s.player_name == name:
            return s
    print(f"ERROR: 找不到房間「{name}」，可用房間：{[s.player_name for s in speakers]}")
    sys.exit(1)

def cmd_list(room: str):
    s = get_speaker(room)
    playlists = s.get_sonos_playlists()
    if not playlists:
        print("目前沒有播放清單")
        return
    for i, pl in enumerate(playlists, 1):
        print(f"{i}. {pl.title}")

def cmd_save(name: str, room: str):
    s = get_speaker(room)
    if s.queue_size == 0:
        print("ERROR: 目前 queue 是空的，無法儲存")
        sys.exit(1)
    # Check if playlist with same name already exists
    existing = [pl for pl in s.get_sonos_playlists() if pl.title == name]
    if existing:
        # Clear and refill
        s.clear_sonos_playlist(existing[0])
        pl = existing[0]
        for item in s.get_queue(max_items=500):
            s.add_item_to_sonos_playlist(item, pl)
    else:
        pl = s.create_sonos_playlist_from_queue(title=name)
    count = s.queue_size
    print(f"OK: 已儲存為「{name}」（共 {count} 首）")

def cmd_play(name: str, room: str):
    s = get_speaker(room)
    playlists = s.get_sonos_playlists()
    match = [pl for pl in playlists if pl.title == name]
    if not match:
        print(f"ERROR: 找不到清單「{name}」")
        print("可用清單：")
        for i, pl in enumerate(playlists, 1):
            print(f"{i}. {pl.title}")
        sys.exit(1)
    s.clear_queue()
    tracks = s.music_library.browse(ml_item=match[0])
    if not tracks:
        print(f"ERROR: 清單「{name}」沒有歌曲")
        sys.exit(1)
    s.add_multiple_to_queue(tracks)
    s.play_from_queue(0)
    print(f"OK: 正在播放「{name}」")

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Sonos playlist manager")
    parser.add_argument("command", choices=["list", "save", "play"])
    parser.add_argument("playlist_name", nargs="?", default=None)
    parser.add_argument("--name", default=DEFAULT_ROOM, help="房間名稱")
    args = parser.parse_args()

    if args.command == "list":
        cmd_list(args.name)
    elif args.command == "save":
        if not args.playlist_name:
            print("ERROR: 請提供清單名稱，例如: save \"爵士夜\"")
            sys.exit(1)
        cmd_save(args.playlist_name, args.name)
    elif args.command == "play":
        if not args.playlist_name:
            print("ERROR: 請提供清單名稱，例如: play \"爵士夜\"")
            sys.exit(1)
        cmd_play(args.playlist_name, args.name)

if __name__ == "__main__":
    main()
```

- [ ] **Step 3: Smoke test list**

```bash
python3 /Users/Modema11434/Documents/Life-OS/scripts/playlist-manager.py list
```
Expected: numbered list of existing playlists (e.g. `1. Qobuz HiFi Jazz`)

- [ ] **Step 4: Smoke test save**

```bash
# First queue a track manually via Sonos app or:
python3 /Users/Modema11434/Documents/Life-OS/scripts/playlist-manager.py save "測試清單"
```
Expected: `OK: 已儲存為「測試清單」（共 N 首）`

Then verify it appears:
```bash
python3 /Users/Modema11434/Documents/Life-OS/scripts/playlist-manager.py list
```
Expected: `測試清單` appears in list.

- [ ] **Step 5: Smoke test play**

```bash
python3 /Users/Modema11434/Documents/Life-OS/scripts/playlist-manager.py play "測試清單"
```
Expected: `OK: 正在播放「測試清單」` and 書房開始播放。

- [ ] **Step 6: Test error case — empty name**

```bash
python3 /Users/Modema11434/Documents/Life-OS/scripts/playlist-manager.py play "不存在的清單"
```
Expected: `ERROR: 找不到清單「不存在的清單」` followed by available list.

---

## Task 2: Create `playlist-manager.sh`

**Files:**
- Create: `scripts/playlist-manager.sh`

- [ ] **Step 1: Write the bash wrapper**

```bash
cat > /Users/Modema11434/Documents/Life-OS/scripts/playlist-manager.sh << 'EOF'
#!/bin/bash
# Sonos playlist manager wrapper
exec python3 "$(dirname "$0")/playlist-manager.py" "$@"
EOF
chmod +x /Users/Modema11434/Documents/Life-OS/scripts/playlist-manager.sh
```

- [ ] **Step 2: Test wrapper**

```bash
/Users/Modema11434/Documents/Life-OS/scripts/playlist-manager.sh list
```
Expected: same numbered list as Task 1 Step 3.

- [ ] **Step 3: Commit**

```bash
cd /Users/Modema11434/Documents/Life-OS
git add scripts/playlist-manager.py scripts/playlist-manager.sh
git commit -m "feat: add Sonos playlist manager (list/save/play)"
```

---

## Task 3: Update SKILL.md

**Files:**
- Modify: `skills/sonoscli/SKILL.md`

- [ ] **Step 1: Add playlist section to SKILL.md**

Append the following section before `## Notes` in `skills/sonoscli/SKILL.md`:

```markdown
## 播放清單管理（Sonos 原生清單）

使用 `playlist-manager.sh` 管理 Sonos 系統播放清單（不含串流服務清單）。

### 子指令

```bash
# 列出所有清單
bash ~/Documents/Life-OS/scripts/playlist-manager.sh list [--name "書房"]

# 把目前 queue 存成清單
bash ~/Documents/Life-OS/scripts/playlist-manager.sh save "清單名稱" [--name "書房"]

# 播放指定清單
bash ~/Documents/Life-OS/scripts/playlist-manager.sh play "清單名稱" [--name "書房"]
```

### 觸發關鍵字

| 使用者說 | 執行 |
|---------|------|
| 列出清單 / 我的清單 / 有哪些清單 | `playlist-manager.sh list` |
| 存成清單「名稱」/ 存下來叫「名稱」 | `playlist-manager.sh save "名稱"` |
| 放清單「名稱」/ 播放清單「名稱」 | `playlist-manager.sh play "名稱"` |

### LINE 回應格式

**list：**
```
🎵 播放清單（共 N 個）
1. 爵士夜
2. 晨間輕音樂
[[quick_replies: 放清單 爵士夜, 放清單 晨間輕音樂]]
```

**save：**
```
✅ 已儲存為「爵士夜」（共 N 首）
```

**play：**
```
▶️ 正在播放「爵士夜」
```
（接著呼叫 `sonos status --name "書房"` 取得曲目資訊，走現有播放狀態回饋流程）
```

- [ ] **Step 2: Verify section was added correctly**

```bash
grep -n "播放清單管理" /Users/Modema11434/Documents/Life-OS/skills/sonoscli/SKILL.md
```
Expected: line number with `播放清單管理` heading.

---

## Task 4: Update CLAUDE.local.md routing

**Files:**
- Modify: `CLAUDE.local.md`

- [ ] **Step 1: Add 3 routing rows to the skill routing table**

In `CLAUDE.local.md`, add these rows to the routing table (before the `| 「建 web app」` row):

```
| 「列出清單」「我的清單」「有哪些清單」 | `sonoscli` playlist-manager list |
| 「存成清單」「存下來叫」+ 名稱 | `sonoscli` playlist-manager save |
| 「放清單」+ 名稱 / 「播放清單」+ 名稱 | `sonoscli` playlist-manager play |
```

- [ ] **Step 2: Commit all skill updates**

```bash
cd /Users/Modema11434/Documents/Life-OS
git add skills/sonoscli/SKILL.md CLAUDE.local.md
git commit -m "feat: add playlist manager routing and SKILL.md section"
```

---

## Task 5: End-to-end verification

- [ ] **Step 1: Test full flow via bash (simulating Telegram trigger)**

```bash
# 1. List
bash ~/Documents/Life-OS/scripts/playlist-manager.sh list
# Expected: 6+ playlists listed (e.g. Qobuz HiFi Jazz, 張國榮, etc.)

# 2. Play an existing playlist
bash ~/Documents/Life-OS/scripts/playlist-manager.sh play "張國榮"
# Expected: OK: 正在播放「張國榮」 and music starts

# 3. Save current queue (after step 2 loads it)
bash ~/Documents/Life-OS/scripts/playlist-manager.sh save "測試清單E2E"
# Expected: OK: 已儲存為「測試清單E2E」

# 4. Verify it appears in list
bash ~/Documents/Life-OS/scripts/playlist-manager.sh list | grep "測試清單E2E"
# Expected: line with 測試清單E2E
```

- [ ] **Step 2: Clean up test playlist**

```bash
python3 -c "
import soco
s = [x for x in soco.discover() if x.player_name == '書房'][0]
pls = [p for p in s.get_sonos_playlists() if p.title == '測試清單E2E']
if pls:
    s.remove_sonos_playlist(pls[0])
    print('cleaned up')
"
```

- [ ] **Step 3: Final commit with plan reference**

```bash
cd /Users/Modema11434/Documents/Life-OS
git add docs/superpowers/
git commit -m "docs: add sonos playlist manager spec and plan"
```
