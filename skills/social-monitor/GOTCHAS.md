# GOTCHAS.md — social-monitor

## G1: Reddit JSON API vs OAuth API

**錯誤**：認為沒有 OAuth 就無法抓 Reddit。
**正確**：reddit.com/search.json 是公開 API，不需要 token，加 User-Agent 即可。
**觸發情境**：Reddit API 審核還沒通過時。

## G2: X 沒有公開 API

**錯誤**：嘗試用 curl 直接抓 twitter.com/search。
**正確**：X 已關閉公開 API，必須用 snscrape 或直接標注跳過。不要嘗試 scrape twitter.com，會被 block。
**觸發情境**：想抓 X/Twitter 資料時。

## G3: PTT 需要 over18 Cookie

**錯誤**：直接 curl PTT 得到跳轉頁面。
**正確**：加上 `-H "Cookie: over18=1"` Header。
**觸發情境**：抓 PTT 任何版面。
