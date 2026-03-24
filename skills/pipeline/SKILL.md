---
name: pipeline
description: 任務輸送帶。讀 backlog.json，找第一個未完成的 story，執行下一個 phase，推 Telegram 進度。一次 cron 只推進一個 phase。觸發詞：輸送帶、pipeline、推進任務、下一步、backlog 狀態
version: 1.0.0
---

# Pipeline — 任務輸送帶

## 設計理念

- **Backlog 是輸入**：任何開放任務清單都可以是 backlog
- **Phase 是狀態機**：null = 待執行，ISO 時間戳 = 完成
- **Cron 是引擎**：定時喚醒，找第一個阻塞點，推進一步
- **一次一個 phase**：做完就停，等下次 cron 再推
- **人類不在關鍵路徑上**：中間環節由 AI 紅隊審查替代人工，產出放到待審區，人類只在最後確認品質

## 自動化原則

**絕對不允許：**
- 「要繼續嗎？」「你確認嗎？」等待人類許可才推進
- 因為人類在睡覺/外出而停擺

**正確做法：**
- 每個 phase 結束後，若下一 phase 標記 `needs_review: true`，自動呼叫紅隊審查
- 紅隊通過 → 繼續；紅隊拒絕 → 標 `blocked`，推 Telegram 說明原因
- 最終產出放到 `待審區`（Vault `60_Deliverables/staging/`），Telegram 通知人類上線確認

## 紅隊審查（自動）

當 phase 設定 `needs_review: true` 時，執行以下流程：

1. 把本次 phase 產出整理成審查摘要
2. 用新的 claude CLI 呼叫（獨立 process，不污染主 context）：
   ```bash
   echo "審查任務：[摘要]" | claude --print --model claude-sonnet-4-6 \
     --system "你是紅隊審查員。判斷這個輸出是否符合品質標準。只回答 PASS 或 FAIL，附上一句理由。"
   ```
3. 回傳 PASS → 標記該 phase 完成，繼續推進
4. 回傳 FAIL → 標 `blocked`，把理由推 Telegram，等下次 cron 重試（最多 3 次）

---

## Backlog 格式

```json
{
  "id": "WO-XXX",
  "title": "任務集名稱",
  "phases": ["s1", "s2", "s3"],
  "phase_labels": {
    "s1": "設計",
    "s2": "實作",
    "s3": "驗證"
  },
  "stories": [
    {
      "id": 1,
      "title": "任務標題",
      "owner": "阿普",
      "complexity": "S",
      "status": "pending",
      "note": "任務說明或來源備註",
      "phases": { "s1": null, "s2": null, "s3": null }
    }
  ]
}
```

**Phase 值說明：**
- `null` = 尚未執行
- `"2026-03-24T10:00:00Z"` = 已完成（ISO 時間戳）

**Story status：**
- `pending` = 還沒開始
- `in_progress` = 至少一個 phase 完成
- `done` = 全部 phase 完成
- `blocked` = 需要人工介入

---

## 執行流程

### Step 1：Lock 防重入

```bash
LOCK="/tmp/pipeline-$(basename $BACKLOG_PATH .json).lock"
if [ -f "$LOCK" ]; then
  echo "Pipeline 已在執行中，跳過" && exit 0
fi
echo $$ > "$LOCK"
trap "rm -f $LOCK" EXIT
```

### Step 2：讀 Backlog

```bash
BACKLOG_PATH="${1:-skills/pipeline/backlog.json}"
cat "$BACKLOG_PATH"
```

找第一個 `status != "done"` 且 `status != "blocked"` 的 story。
若全部 done → 執行「Step 6：完工」。

### Step 3：找下一個 null phase

在找到的 story 裡，依序掃 phases（s1 → s2 → ...），找第一個值為 `null` 的 phase。

這就是本次要執行的任務。

### Step 4：執行 Phase

**執行前先確認：**

```bash
echo "即將執行：Story #${id} ${title} — Phase ${phase}（${phase_label}）"
echo "說明：${note}"
```

**依據 story 的 note 和 phase 執行對應工作。**
每個 backlog 的 phase 意義由 `phase_labels` 定義，以下是預設四段：

| Phase | 預設名稱 | 做什麼 |
|-------|---------|--------|
| s1 | 設計 | 讀現有資料，產出規格或草稿 |
| s2 | 建置 | 實作主體內容（寫 skill、腳本、文件） |
| s3 | 測試 | 驗證功能正確性，記錄結果 |
| s4 | 收尾 | 整理產出、更新索引、通知相關人 |

> **安全閘門：**
> - 建新檔案、建目錄 → 直接執行
> - 修改現有重要檔案 → 先備份再改
> - 任何不確定的操作 → 停下來問，不自己猜

### Step 5：更新 Backlog

Phase 完成後，立即更新 `backlog.json`：

```python
import json, datetime, sys

path = sys.argv[1]
story_id = int(sys.argv[2])
phase = sys.argv[3]

with open(path) as f:
    data = json.load(f)

now = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")

for s in data["stories"]:
    if s["id"] == story_id:
        s["phases"][phase] = now
        # 第一個 phase 完成 → in_progress
        if all(v is None for k, v in s["phases"].items() if k != phase):
            s["status"] = "in_progress"
        # 全部 phase 完成 → done
        if all(v is not None for v in s["phases"].values()):
            s["status"] = "done"
        break

with open(path, "w") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print(f"Updated: story #{story_id} phase {phase} = {now}")
```

### Step 6：推 Telegram 進度

```
📦 Pipeline 進度 — {wo_id}

✅ #{story_id} {title}
   Phase：{phase_label} 完成

⏭️ 下一步：{next_story_title} — {next_phase_label}
（或「本批次全部完成」）

📊 進度：{done_count}/{total_count} 個任務完成
```

使用 `mcp__plugin_telegram_telegram__reply` 推送。

---

## Step 6：完工處理

當所有 story 都是 `done` 時：

1. 推 Telegram 完工摘要：

```
🎉 Pipeline 完成 — {wo_id}

{每個 story 的完成時間摘要}

共 {N} 個任務，{total_phases} 個 phase 全部完成。
```

2. 若有設定 cron，提示用戶是否要停止：
   「WO-{id} 全部完成，要我停止這個輸送帶 cron 嗎？」

---

## 手動觸發

說「pipeline {backlog路徑}」或「推進任務 {backlog路徑}」時，立即執行一次（不等 cron）。
說「backlog 狀態」或「輸送帶進度」時，只讀取並顯示狀態，不執行 phase。

---

## 錯誤處理

| 情境 | 處理 |
|------|------|
| backlog.json 不存在 | 推 Telegram 錯誤，停止 |
| Story status = blocked | 跳過，找下一個 pending/in_progress |
| Phase 執行失敗 | 不更新 backlog，推 Telegram 錯誤，等下次 cron 重試（最多 3 次後標 blocked） |
| Lock 存在超過 30 分鐘 | 強制清除 lock，重新執行 |

---

## 新建任務集

1. 複製 `skills/pipeline/backlog-template.json`
2. 填入 stories 和 phases
3. 說「pipeline {路徑}」或設 cron 讓它自動跑
