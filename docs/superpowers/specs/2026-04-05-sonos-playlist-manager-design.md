# Sonos Playlist Manager — Design Spec

**Date:** 2026-04-05
**Status:** Approved

## Problem

現有 sonoscli skill 缺少播放清單管理功能：無法快速列出清單、存下當前 queue、或叫名稱播清單。

## Scope

三個動作：**列出、存成、播放**。不做備份/還原（非需求）。

**範圍限制：** 僅操作 Sonos 系統原生播放清單（Sonos Playlists），不延伸到 Spotify、Qobuz、TIDAL 等串流服務的播放清單。

## Architecture

```
scripts/playlist-manager.sh   ← bash 入口，Claude 直接呼叫
scripts/playlist-manager.py   ← soco Python 實作
```

### 子指令

| 指令 | 動作 |
|------|------|
| `playlist-manager.sh list [--name <房間>]` | 列出所有 Sonos 播放清單，回傳編號 + 名稱 |
| `playlist-manager.sh save "<名稱>" [--name <房間>]` | 把指定房間目前 queue 存成 Sonos 播放清單 |
| `playlist-manager.sh play "<名稱>" [--name <房間>]` | 載入指定清單到房間並開始播放 |

**預設房間：** `書房`

### Python 實作（soco）

```python
import soco

# list
playlists = soco.discover()  # 從任一 speaker 取清單
sp = speaker.get_sonos_playlists()

# save
pl = speaker.create_sonos_playlist(name)
for track in speaker.get_queue():
    speaker.add_uri_to_sonos_playlist(track.uri, pl)

# play
pl = [p for p in speaker.get_sonos_playlists() if p.title == name][0]
speaker.clear_queue()
speaker.add_sonos_playlist_to_queue(pl)
speaker.play_from_queue(0)
```

## SKILL.md 新增段落

在 sonoscli SKILL.md 加入「播放清單管理」章節，包含：
- 三個子指令說明
- 觸發關鍵字：`列出清單`、`存成清單`、`播放清單`、`清單叫什麼`
- LINE 回應格式（見下方）

## LINE 回應格式

**list：**
```
🎵 播放清單（共 N 個）
1. 爵士夜
2. 晨間輕音樂
3. 工作背景
[[quick_replies: 放 1, 放 2, 放 3]]
```

**save：**
```
✅ 已儲存為「爵士夜」（共 N 首）
```

**play：**
```
▶️ 正在播放「爵士夜」
（接著走現有播放狀態回饋流程）
```

## CLAUDE.local.md 路由更新

新增觸發條件：
```
| 「列出清單」「我的清單」「有哪些清單」 | sonoscli playlist-manager list |
| 「存成清單」「存下來」+ 名稱 | sonoscli playlist-manager save |
| 「放清單」+ 名稱 / 「播放清單」+ 名稱 | sonoscli playlist-manager play |
```

## Error Handling

- 清單名稱找不到 → 列出所有清單讓用戶選
- soco discover 失敗 → 提示 Local Network 權限
- save 時 queue 是空的 → 告知無法儲存空 queue

## 驗收條件

1. `playlist-manager.sh list` 回傳至少一筆（或回「目前沒有清單」）
2. `save "測試清單"` 後 `list` 能看到這個名稱
3. `play "測試清單"` 後書房開始播放
4. 全程從 Telegram 自然語言觸發，不需要輸入指令
