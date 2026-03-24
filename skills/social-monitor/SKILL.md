---
name: social-monitor
description: 定期抓取 Reddit/PTT 訂閱版面的最新內容，生成摘要推送 Telegram。使用時機：社群動態、輿情、PTT 在說什麼、Reddit 有什麼討論。
---

# Social Monitor — 社群版面監控

## Overview

訂閱 Reddit/PTT 版面 → 定期抓最新內容 → AI 摘要 → 推 Telegram。
Dcard/Threads 不納入每日輪巡（臨時想看摘要時用 capture skill 處理）。

## 設定檔

監控 URL 清單存在：
```
skills/social-monitor/urls.md
```
格式見下方「URL 清單管理」。

---

## Step 1：逐 URL 抓取內容

依設定檔逐條抓取，每個平台用對應方式：

### Reddit（JSON API）

```bash
URL="$1"   # 例：https://www.reddit.com/r/ClaudeAI/new/
curl -s -A "LifeOS-Monitor/1.0" "${URL}.json?limit=25" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
posts = data['data']['children']
for p in posts[:10]:
    d = p['data']
    print(f\"r/{d['subreddit']} | {d['score']}↑ | {d['title'][:80]}\")
    print(f\"  {d.get('selftext','')[:100]}\")
    print()
"
```

### PTT（HTML 抓取）

```bash
URL="$1"   # 例：https://www.ptt.cc/bbs/ChatGPT/index.html
curl -s "$URL" -H "Cookie: over18=1" \
  | python3 -c "
import sys, re
content = sys.stdin.read()
titles = re.findall(r'class=\"title\">\s*<a href=\"([^\"]+)\">([^<]+)', content)
for url, title in titles[:10]:
    print(f'PTT | {title.strip()}')
    print(f'  https://www.ptt.cc{url}')
    print()
" 2>/dev/null || echo "PTT: 抓取失敗，跳過"
```

---

## Step 2：AI 摘要

將所有抓取結果整合，針對每個 URL 來源輸出：
- 今日新增貼文數量
- 2-3 句主要討論方向
- 值得注意的高互動或異常內容

---

## Step 3：推送 Telegram

輸出格式：
```
👁 社群動態 YYYY-MM-DD HH:MM

【r/ClaudeAI】
• 主要討論：...（N 篇新文）

【PTT/ChatGPT】
• ...（N 篇新文）

【Dcard/3C】
• ...（N 篇新文）

⚠️ 值得注意
• 異常高熱度或特別內容
```

---

## URL 清單管理

新增監控目標：直接在 `skills/social-monitor/urls.md` 加一行 URL。

格式：
```
## 類別名稱
| 平台 | 名稱 | URL |
|------|------|-----|
| Reddit | ClaudeAI | https://www.reddit.com/r/ClaudeAI/new/ |
| PTT | ChatGPT板 | https://www.ptt.cc/bbs/ChatGPT/index.html |
```

---

## 備註

- 每個 URL 失敗都靜默跳過，不中斷整體流程
- Threads 頁面結構不穩定，失敗率較高，遇到失敗直接跳過
- Reddit API 審核通過後可改用 mcp-reddit，準確度更高
- 設定檔不存在時，提示用戶建立，不自動執行
