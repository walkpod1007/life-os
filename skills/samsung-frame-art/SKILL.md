---
name: samsung-frame-art
description: Samsung Frame TV 換畫：從 Artvee 自動抓取世界名畫，或從 TMDB 推送電影海報，合成後上傳到 Frame TV。使用時機：換電視畫、frame art、今日畫作、換海報、frame tv、幫我換畫、daily art、換一張名畫、推電影海報、tmdb 海報。不觸發：查電視狀態（用 smart-home）、播音樂（用 sonoscli）。
---

# Samsung Frame Art

> ⚠️ **版面規格已定案（v1.1.0，2026-03-24）**
> 非必要不要更動 compose-poster.py 的版面邏輯。更動前先看 CHANGELOG.md。

## Overview

每日自動換畫，或手動推送電影海報到 Frame TV。

## 模式一：世界名畫（Artvee）

```bash
cd ~/lobster-skills/skills/frame-daily-art

# 抓畫作（高解析、豎向優先）
python3 scripts/fetch-artvee.py \
  --min-px 2000 \
  --portrait-ratio 1.3 \
  --exclude-log data/used-artworks.json

# 合成 InfoBar + 上傳
python3 scripts/compose-and-upload.py --latest
```

## 模式二：TMDB 電影海報

```bash
# 1. 搜尋電影取得 ID（用中文搜尋沒問題）
curl -s "https://api.themoviedb.org/3/search/movie?query=<片名>&language=zh-TW&api_key=$TMDB_API_KEY" | jq '.results[:3] | .[] | {id, title, original_title, release_date}'

# 2. 取 original_title + 導演（原文）
curl -s "https://api.themoviedb.org/3/movie/<id>?api_key=$TMDB_API_KEY&language=<原文語言>&append_to_response=credits" | jq '{original_title, original_language, director: [.credits.crew[] | select(.job=="Director") | .name]}'

# 3. 下載最高評分海報
curl -s "https://api.themoviedb.org/3/movie/<id>/images?api_key=$TMDB_API_KEY&include_image_language=<lang>,en,null" | jq '.posters | sort_by(-.vote_average) | .[0].file_path'
curl -o /tmp/poster-raw.jpg "https://image.tmdb.org/t/p/original/<file_path>"

# 4. 合成 + 上傳
echo '{"title":"<原文片名>","artist":"<原文導演>","year":"<年份>"}' > /tmp/meta.json
python3 ~/lobster-skills/skills/frame-daily-art/scripts/compose-poster.py \
  --input /tmp/poster-raw.jpg --meta /tmp/meta.json --output /tmp/poster-final.jpg
python3 ~/.openclaw/skills/samsung-smartthings/scripts/upload_to_frame.py /tmp/poster-final.jpg
```

## 片名 / 導演語言原則

**一律用原文，不翻譯：**

| 片源 | 片名 | 導演 |
|------|------|------|
| 英語片 | Good Will Hunting | Gus Van Sant |
| 日本片 | 千と千尋の神隱し | 宮崎 駿 |
| 韓國片 | 기생충 | 봉준호 |
| 法語片 | Amélie | Jean-Pierre Jeunet |

TMDB 查詢時：用 `original_title` 作為片名；導演用 `language=<original_language>` 查詢取得原文名。

## 自動排程

每日 08:00（Asia/Taipei）自動換名畫。

## 前置條件

- Python3 + Pillow、requests、beautifulsoup4
- Frame TV 與 Mac 同一局域網
- SmartThings 憑據（from `samsung-smartthings` skill）
- TMDB API key（電影海報模式）

## InfoBar 字體規格

底部 InfoBar 字體優先序（支援繁體中文）：
- **標題**：STHeiti Medium → STHeiti Light → Georgia Bold → Arial Bold
- **副標**：STHeiti Light → Georgia → Arial Unicode

中文字元（如「心靈捕手」）需 STHeiti；英文/英數自動 fallback 到 Georgia。
系統字體路徑：`/System/Library/Fonts/STHeiti Medium.ttc`

## 腳本位置

```
~/lobster-skills/skills/frame-daily-art/
├── scripts/fetch-artvee.py
├── scripts/compose-and-upload.py
├── scripts/tmdb-poster.py
└── data/used-artworks.json
```
