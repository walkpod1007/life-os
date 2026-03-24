# Step 2D：Threads 專用流程（純 HTTP，零 Relay）

Threads 是 Meta 三平台中最乾淨的——一次 curl 就能拿到全文、首圖、作者。

**Step 2D-1：curl 抓頁面**

```bash
curl -sL -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
  "$URL" -o /tmp/threads-capture.html
```

⚠️ URL 中的 `?xmt=...` 參數可留可去，不影響結果。

**Step 2D-2：解析 OG tags（摘要 + 首圖）**

```bash
python3 -c "
import re, html as h
with open('/tmp/threads-capture.html','r') as f: content=f.read()
for tag in ['og:title','og:description','og:image']:
    m = re.search(r'property=\"' + tag + r'\" content=\"([^\"]+)\"', content)
    if m: print(f'{tag}: {h.unescape(m.group(1))}')
"
```

- `og:description` 是摘要（可能被截斷）
- `og:image` 是首圖 CDN URL（只有第一張，多圖輪播拿不到其餘）
- 首圖必須下載 + OCR（見 Step 2D-4）

**Step 2D-3：解析 ServerJS JSON（全文）⭐ 關鍵步驟**

全文藏在 HTML 的 `<script type="application/json" data-sjs>` 裡的 `meta.title` 欄位：

```bash
python3 -c "
import re, json
with open('/tmp/threads-capture.html','r') as f: content=f.read()
# 找 ServerJS JSON 中的 meta.title（包含完整貼文）
matches = re.findall(r'\"title\":\"((?:[^\"\\\\\\\\]|\\\\\\\\.)*)\"', content)
for m in matches:
    if len(m) > 100:  # 短的是頁面標題，長的才是貼文全文
        # Unicode 解碼
        text = m.encode('utf-8').decode('unicode_escape', errors='replace')
        print(text)
        break
"
```

⚠️ 注意事項：
- `title` 欄位的 Unicode 是 `\uXXXX` 格式，需 `decode('unicode_escape')`
- 短的 title（< 100 字元）是頁面標題，跳過；長的才是貼文全文
- 如有 surrogate 字元（emoji），用 `errors='replace'` 防止崩潰
- 多圖 / 留言都是 client-side GraphQL 載入，curl 拿不到——但 Threads 以文字為主，首圖+全文已夠用

**Step 2D-4：下載首圖 + OCR（必做）**

Threads 貼文常搭配資訊圖表、截圖、長文卡片，圖片裡的文字可能是內容核心。首圖一定抓、一定 OCR。

```bash
# 從 og:image 下載（URL 中的 &amp; 要還原成 &）
python3 -c "
import re, html as h
with open('/tmp/threads-capture.html','r') as f: content=f.read()
m = re.search(r'og:image\" content=\"([^\"]+)\"', content)
if m: print(h.unescape(m.group(1)))
" | xargs -I{} curl -sL "{}" -o /tmp/threads-image.jpg
```

然後用 `image` 工具 OCR：
> 「這是 Threads 貼文的配圖。提取圖片中所有文字內容，保持原始排版。如果是純照片無文字，簡要描述圖片內容。」

將 OCR 結果併入全文一起摘要。圖片裡的資訊和正文同等重要。

⚠️ og:image URL 有時效性（CDN token 會過期），抓到 HTML 就立刻下載，不要等。

**Step 2D-5：解析作者**

作者在 OG title 中：格式為 `顯示名稱 (@username) on Threads`

```bash
python3 -c "
import re
with open('/tmp/threads-capture.html','r') as f: content=f.read()
m = re.search(r'og:title\" content=\"([^\"]+)\"', content)
if m:
    title = m.group(1)
    # 提取 @username
    um = re.search(r'\(@([^)]+)\)', title)
    if um: print(f'@{um.group(1)}')
"
```

**Step 2D-6：清除暫存**
```bash
rm -f /tmp/threads-capture.html /tmp/threads-image.jpg
```

