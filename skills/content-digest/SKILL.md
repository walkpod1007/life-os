---
name: content-digest
description: 定時從 YouTube 訂閱、Podcast、RSS 抓最新內容，去重分類後推 Telegram 一份摘要。使用時機：今天有什麼新內容、內容摘要、有什麼新影片、新集數、今天的資訊。
---

# Content Digest — 跨平台內容聚合器

## Overview

YouTube + Podcast + RSS → 去重分類 → AI 摘要 → 推 Telegram。
每 8 小時自動跑，也可手動觸發。
依賴：youtube-grabber、podcast-grabber（已在 skills/）。

## 設定檔

```
~/.claude/projects/-Users-Modema11434-Documents-Life-OS/config/content-digest.json
```

格式：
```json
{
  "youtube_channels": [
    {"id": "UCxxxxxx", "name": "Peter Yang"},
    {"id": "UCyyyyyy", "name": "Artem"}
  ],
  "podcast_feeds": [
    {"url": "https://feeds.example.com/podcast.rss", "name": "某 Podcast"}
  ],
  "rss_feeds": [
    {"url": "https://hnrss.org/frontpage", "name": "Hacker News 精選"}
  ]
}
```

設定檔不存在時提示用戶建立，不自動跑。

## Step 1：抓 YouTube 最新影片（過去 8 小時）

```bash
CONFIG="$HOME/.claude/projects/-Users-Modema11434-Documents-Life-OS/config/content-digest.json"
SINCE=$(date -v-8H +%Y-%m-%dT%H:%M:%SZ)   # macOS

# 逐個頻道查
python3 -c "
import json, subprocess, sys
config = json.load(open('$CONFIG'))
for ch in config.get('youtube_channels', []):
    result = subprocess.run([
        'yt-dlp', '--flat-playlist', '--print', '%(upload_date>%Y-%m-%d)s|%(title)s|%(url)s',
        '--date-after', '$(date -v-1d +%Y%m%d)',
        f'https://www.youtube.com/channel/{ch[\"id\"]}/videos'
    ], capture_output=True, text=True)
    for line in result.stdout.strip().split('\n'):
        if line:
            print(f'YT|{ch[\"name\"]}|{line}')
" 2>/dev/null
```

## Step 2：抓 Podcast 最新集數

```bash
# 用 podcast-grabber skill 的邏輯
python3 -c "
import json, urllib.request, xml.etree.ElementTree as ET
config = json.load(open('$CONFIG'))
for feed in config.get('podcast_feeds', []):
    try:
        req = urllib.request.Request(feed['url'], headers={'User-Agent': 'LifeOS/1.0'})
        xml_data = urllib.request.urlopen(req, timeout=10).read()
        root = ET.fromstring(xml_data)
        items = root.findall('.//item')[:3]
        for item in items:
            title = item.findtext('title', '')
            pub = item.findtext('pubDate', '')
            print(f'POD|{feed[\"name\"]}|{pub[:16]}|{title}')
    except Exception as e:
        print(f'POD|{feed[\"name\"]}|FAIL|{e}', file=__import__(\"sys\").stderr)
" 2>/dev/null
```

## Step 3：抓 RSS

```bash
python3 -c "
import json, urllib.request, xml.etree.ElementTree as ET
config = json.load(open('$CONFIG'))
for feed in config.get('rss_feeds', []):
    try:
        req = urllib.request.Request(feed['url'], headers={'User-Agent': 'LifeOS/1.0'})
        xml_data = urllib.request.urlopen(req, timeout=10).read()
        root = ET.fromstring(xml_data)
        items = root.findall('.//item')[:5]
        for item in items:
            title = item.findtext('title', '')
            print(f'RSS|{feed[\"name\"]}|{title[:80]}')
    except Exception as e:
        print(f'RSS|{feed[\"name\"]}|FAIL', file=__import__(\"sys\").stderr)
" 2>/dev/null
```

## Step 4：去重 + AI 分類摘要

將三個來源的輸出合併，讓 AI：
1. 去除重複項目（同一個內容多個來源）
2. 按主題分類（AI 技術、生產力、其他）
3. 每項用 1 句話說重點

## Step 5：推送 Telegram

輸出格式：
```
📦 內容聚合 YYYY-MM-DD HH:MM
共 N 篇新內容

🤖 AI / 技術
• [Peter Yang] 影片標題 — 重點一句話
• [Hacker News] 文章標題

⚙️ 生產力
• [某 Podcast] 集數標題

📌 其他
• ...
```

超過 10 項 → 只列前 10，標注「還有 N 項，說『展開』看全部」。

## 備註

- 設定檔需要手動建立（yaml 格式），skill 不自動設定頻道清單
- 各平台失敗靜默跳過，不中斷整體
- 結果可選存到 Vault `00_Inbox/content-digest-YYYY-MM-DD.md`
- 50 個頻道清單設定完成後，content-digest 就能全自動聚合
