# GOTCHAS.md — capture skill

> 格式：**錯誤描述** / **正確做法** / **觸發情境**
> 這些都是真實踩過的坑，改 skill 前先讀這裡。

---

## G1: IG 不能用 curl OG tags 取代 Browser Relay

**錯誤**：認為 curl 抓 OG tags 就夠了，繞過 Browser Relay 節省時間。
**正確**：curl OG tags 只拿到 caption + 第一張圖，IG 輪播圖片中大量內容在後續圖片的圖片文字裡，全部遺失。IG 必須走 Browser Relay。
**觸發情境**：擷取 Instagram 帖文 URL，特別是含多張圖片的輪播貼文。

---

## G2: 不要自作聰明修改設計決策

**錯誤**：看到「IG 走 Browser Relay」覺得多此一舉，直接改成 curl 方案。
**正確**：每個設計決策背後有原因。不理解意圖就別改，先讀 SKILL.md 和 GOTCHAS 了解為什麼，再問用戶確認。
**觸發情境**：覺得現有方案「太複雜」想簡化的時候。

---

## G3: Vault 圖片不能直接用於外部顯示

**錯誤**：把圖片存到 Vault 後用 vault URL 做預覽。
**正確**：Vault 有 Cloudflare Access 保護，外部讀不到。圖片存到 `00_Inbox/attachments/`，外部預覽用 og_image 原始 URL 或不顯示圖。
**觸發情境**：想在 Telegram 回覆中顯示擷取到的圖片。

---

## G4: 產出必須落地 Vault 才算完成

**錯誤**：任務完成了，但筆記只存在 session 記憶，沒有寫到 Vault。
**正確**：每次擷取完成後必須寫 Obsidian `00_Inbox/`。session 結束後未落地的產出會消失。交付前用 `ls` 確認檔案實際存在。
**觸發情境**：擷取長文章、社群貼文後，任務結案。

---

## G5: Threads / X / 非 IG 平台不需要 Browser Relay

**錯誤**：因為 IG 用 Browser Relay，就把所有平台都走 Browser Relay。
**正確**：Browser Relay 只用於需要 JS 渲染或有防爬限制的平台（如 IG）。Threads、PTT、知乎等可用直接 HTTP 請求。
**觸發情境**：擷取非 IG 的社群媒體 URL。

---

## G6: IG embed HTML 的 display_url regex 容易寫錯

**錯誤**：用簡單 regex `edge_sidecar_to_children.*display_url` 打不到資料。
**正確**：embed HTML 中 escape 層數特殊（`\\\/` 是 `\\/` 的 escape），用 grep + Python 兩段處理。詳見 refs/platform-instagram.md。
**觸發情境**：擷取 IG 輪播圖片清單。

---

## G7: PTT 八卦板等 18+ 看板必須帶 over18 cookie

**錯誤**：curl 直接抓 PTT 被重定向到年齡確認頁。
**正確**：加 `-H "Cookie: over18=1"` header。
**觸發情境**：抓 PTT 八卦板、表特板等成人版。

---

## G8: YouTube 走 youtube-grabber，不走 summarize

**錯誤**：YouTube URL 用 summarize CLI 抓，品質差且無法進 NotebookLM。
**正確**：YouTube 一律走 youtube-grabber skill（yt_notebook_pipeline.py），產出結構化摘要 + 可匯入 NotebookLM。
**觸發情境**：偵測到 youtube.com 或 youtu.be URL。

---

## G9: Reddit MCP 需要先安裝設定

**錯誤**：呼叫 Reddit MCP 工具但沒有安裝。
**正確**：Reddit MCP（mcp-reddit）需先安裝並在 .mcp.json 設定。安裝前降級用 web_fetch 抓 Reddit 頁面。
**觸發情境**：擷取 reddit.com URL 時。
