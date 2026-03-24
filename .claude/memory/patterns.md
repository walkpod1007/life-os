---
name: Learned Patterns
description: 派工成功案例、失敗教訓、通用原則、最佳實踐
type: feedback
---

# Learned Patterns — 經驗累積

## ✅ 成功案例

### 1. YouTube 摘要 → Gemini
**情境**：用戶提供 YouTube 連結，要求 800 字繁體中文摘要

**執行**：
```bash
gemini "請觀看並總結這個 YouTube 影片...800字摘要" URL
```

**結果**：
- ⚡ 30 秒內完成
- 準確度：95%+（涵蓋主要概念、關鍵論點、實用價值）
- Token 消耗：低

**應用**：
- 類似「查一下 X」的任務自動 Gemini
- 不問用戶，直接派工

**案例**：
- NTU Professor Wu Chia-ling sociology lecture (2026-03-23)
- Summary: Giddens' pure relationships, sexual hierarchy, queer theory

---

### 2. 檔案分析 → Codex
**情境**：分析單個檔案的邏輯、bug、改進點

**執行**：
```bash
codex exec -C /path/to/dir/ "分析 file.py..."
```

**結果**：
- ⚡⚡ 1-3 分鐘完成
- 準確度：90%+（邏輯分析、修改建議）
- 可直接用代碼行號參考修改

**應用**：
- 工程審查
- 性能優化建議
- 邏輯澄清

**案例**：
- art-composer.py 縮放模式分析（Cover vs Contain）（2026-03-23）
- Result: 確認目前 Contain，改 min→max = Cover

---

## ❌ 失敗案例 & 修正

### 1. Frame TV 模式概念混亂
**失敗**：
- 摘要記錄說「需要改成 Contain 模式」
- 實際檔案 art-composer.py 已經是 Contain

**根因**：
- 概念搞反（應該是「已經是 Contain，如需 Cover 改 min→max」）
- 沒有用 Codex 驗證假設

**修正**：
- 用 Codex 分析實際代碼，確認現狀
- 更新決策日誌為正確信息

**下次教訓**：
- 遇到「需要改什麼」，先派 Codex 確認當前狀態
- 不要假設摘要記錄一定對

---

### 2. 倒 Gemini 任務時沒帶完整 context
**失敗**：
- 複雜的摘要任務，沒有給足 context
- 結果不夠精確

**修正**：
- Gemini 派工時帶上背景、目標、限制
- 例：「這是為了 X 目的，需要突出 Y，忽略 Z」

---

## 📚 通用教訓

### Rule 1：派工前確認工作目錄
❌ 派工給 Codex 時沒指定 -C
✅ 總是帶上 `-C /exact/path/`

### Rule 2：簡單事不要找 Claude Code
❌ 「幫我查一下 X」→ 直接 Claude Code 搜尋
✅ 「幫我查一下 X」→ 自動 Gemini

### Rule 3：重要決策要立刻寫下來
❌ 邊做邊忘，session 壓縮會丟
✅ 決定時立刻更新 decisions_YYYY-MM.md

### Rule 4：派工後要看結果
❌ 派工後就關掉，沒驗證結果
✅ 等派工完成，確認結果符合預期，再告訴用戶

### Rule 5：遇到歧義先問
❌ 猜測用戶的意思，派錯了
✅ 「你是想要 X 還是 Y？」

---

## 📊 派工成功率追蹤

| 派工對象 | 總次數 | 成功 | 失敗 | 成功率 |
|---------|--------|------|------|--------|
| Gemini | 1 | 1 | 0 | 100% |
| Codex | 1 | 1 | 0 | 100% |
| 龍蝦 | 0 | - | - | - |
| 合計 | 2 | 2 | 0 | 100% |

**目標**：維持 > 95% 的派工成功率

---

## 下次改進

- [ ] 實施「派工前驗證清單」（工作目錄、context、預期結果）
- [ ] 建立派工失敗的快速回復機制
- [ ] 追蹤派工延遲時間（SLA）
- [ ] 自動判斷什麼時候應該派工 vs. 自己做

---

## ✅ 新成功案例

### 3. Vault 重構規劃 → 分步驟慎重執行
**情境**：大規模資料夾重組，涉及多個公開 URL 路徑

**執行**：
- 先設計新結構（不移動）
- 派 Gemini 深掃資料內容
- 逐個資料夾檢查品質
- 建立 .Trash 系統（不直接刪除）
- 定義清楚（Tools.md）

**結果**：
- ⚡ 避免誤刪重要檔案（LINE Rich Menu 資產）
- ⚡ 發現 assets vs island-assets 的差異
- ⚡ 架構清楚，下一步可無縫接續

**下次應用**：
- 大型資料遷移先規劃、掃描、定義
- 分批執行（不要一次全動）
- 使用 Trash 系統保險

---

## 更新日誌

- **2026-03-23** 初版，2 個成功案例 + 2 個失敗教訓
- **2026-03-23** 新增：Vault 重構（案例 3）+ Trash 系統原則
