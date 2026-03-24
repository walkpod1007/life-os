# Step 2C：Instagram 專用流程（輪播圖片 OCR）

IG 的內容大量藏在輪播圖片裡（資訊圖表、長文截圖、教學卡片），caption（og:description）只是摘要。必須抓圖片做 OCR 才能拿到完整內容。

**暫存目錄**：`/tmp/link-capture/ig/`（用完即清）

**Step 2C-1：curl OG tags 拿 caption + 第一張圖**

```bash
mkdir -p /tmp/link-capture/ig
curl -sL -A "Mozilla/5.0" "$URL" | python3 -c "
import sys, re, html, json
content = sys.stdin.read()
result = {}
for tag in ['og:title', 'og:description', 'og:image']:
    m = re.search(r'property=\"' + tag + r'\"[^>]*content=\"([^\"]+)\"', content)
    if not m:
        m = re.search(r'content=\"([^\"]+)\"[^>]*property=\"' + tag + r'\"', content)
    result[tag] = html.unescape(m.group(1)) if m else None
print(json.dumps(result, ensure_ascii=False))
"
```

**Step 2C-2：取得所有輪播圖片（順序保留）**

唯一正式路徑：IG embed endpoint + grep 提取 display_url（實測可靠）。

⚠️ **踩坑紀錄（2026-03-22）**：原本的 regex `edge_sidecar_to_children\\":\\{.*?edge_web_media_to_related_media` 在實際 embed HTML 中打不到，因為 escape 層數不同。改用 grep + Python 兩階段處理才穩定。

```bash
# Step 1：抓 embed HTML 並存檔
curl -sL "https://www.instagram.com/p/${POST_ID}/embed/" -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
  -o /tmp/link-capture/ig/embed.html

# Step 2：grep 提取 display_url 行（比 regex 更穩定）
grep -o 'display_url[^,]*' /tmp/link-capture/ig/embed.html \
| python3 -c '
import sys, re
seen = set()
for line in sys.stdin:
    rest = line.strip().replace("display_url", "", 1)
    m = re.search(r"https?:.+", rest)
    if m:
        url = m.group(0)
        # 實際 raw bytes 是 \\\/ (雙反斜線+/)，需用 replace("\\\\\/", "/") 才能正確解碼
        url = url.replace("\\\\/", "/").rstrip("\\").rstrip("\"")
        if url not in seen and "instagram" in url:
            seen.add(url)
            print(url)
' > /tmp/link-capture/ig/urls.txt

# Step 3：統計張數
SLIDE_COUNT=$(wc -l < /tmp/link-capture/ig/urls.txt)
echo "slides=$SLIDE_COUNT"
```

**硬性驗收（必回報）**
- 執行後必回報：`slides=<數量>`。
- `slides >= 2` 才算成功。
- `slides <= 1` 必須明確標記 `fallback`，不得宣稱已完整抓取。
- 禁止在 Instagram 路由提及或建議 Browser Relay。

### 低階模型防呆版（照抄執行）

1. 從 URL 抽 `POST_ID`（格式：`/p/{POST_ID}/`）。
2. `curl` 抓 `https://www.instagram.com/p/{POST_ID}/embed/` 存到 `/tmp/link-capture/ig/embed.html`。
3. 用 `grep -o 'display_url[^,]*'` 提取所有 display_url 行。
4. 用 Python 解碼 `\/` → `/` 並去重輸出到 `/tmp/link-capture/ig/urls.txt`。
5. 逐張下載成 `slide-01.jpg`、`slide-02.jpg`……（不要跳號）。
6. 逐張 OCR，最後合併 `caption + 所有 slide 文字`。
7. 若最終張數 `<= 1`，輸出警告：`封面圖 fallback，內容可能不完整`。

**Step 2C-3：下載所有圖片到暫存目錄**

```bash
# urls.txt 輸出已在 Step 2 解碼，直接下載（加 Referer header 才能拿到圖）
mkdir -p /tmp/link-capture/ig

IDX=1
while read IMG_URL; do
  curl -sL -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
    -H "Referer: https://www.instagram.com/" \
    "$IMG_URL" -o "/tmp/link-capture/ig/slide-$(printf '%02d' $IDX).jpg"
  IDX=$((IDX+1))
done < /tmp/link-capture/ig/urls.txt

echo "Downloaded $((IDX-1)) slides"
```

**Step 2C-4：OCR 每張圖片**

用 `image` 工具逐張分析，prompt：
> 「這是 Instagram 貼文的第 N 張圖片。提取圖片中所有文字內容，保持原始排版。如果是純照片無文字，描述圖片內容。」

**Step 2C-5：彙整**

將 caption（og:description）+ 每張圖片的 OCR 文字合併為完整原文，送到 Step 4 生成摘要。

**Step 2C-6：清除暫存**

```bash
rm -rf /tmp/link-capture/ig/
```

⚠️ 注意事項：
- OG tags 的圖片 URL 有時效性（CDN token 會過期），要即時下載不要存 URL
- 輪播圖片順序很重要（教學類貼文是有邏輯順序的），按 slide 編號排列
- Reel 類型（影片）不走 OCR，只用 caption

---

## Changelog
- 2026-03-22 v1: 棄用 regex `edge_sidecar_to_children\\":\\{.*?`，改用 `grep -o 'display_url[^,]*'` + Python 解碼。原因：三模型（Flash、MiniMax、Sonnet）都打不到，escape 層數不同。
- 2026-03-22 v1: embed HTML 先存檔再處理，方便 debug。
- 2026-03-22 v1: 強制回報 `slides=<數量>`，驗收門檻 `>= 2`，避免宣稱成功但只抓到封面圖。
- 2026-03-22 v2: 修正 URL 解碼錯誤。原寫法 `.replace("\\/", "/")` 少一層，實際 raw bytes 是 `\\/`，須用 `.replace("\\\\/", "/")` 才能正確還原成 `https://`。下載指令移除多餘的 `sed` 中轉步驟，改為 Step 2 直接輸出乾淨 URL。補上 `-H "Referer: https://www.instagram.com/"` header，缺少時 CDN 回 0 bytes。
