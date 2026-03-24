---
name: roborock
description: 控制 Roborock 掃地機器人：啟動、暫停、回充、查狀態、指定房間、查耗材。使用時機：掃地、吸地板、掃地機器人、roborock、清地板、吸塵器、回充、掃地機回去。
---

# Roborock Vacuum Control

## Overview

用 `roborock` CLI 控制掃地機器人。需先 `roborock login` 登入帳號。

## 安裝（第一次）

```bash
pipx install python-roborock
roborock login          # 輸入 Roborock/小米帳號密碼
roborock list-devices   # 找 device ID
```

## 常用指令

```bash
roborock start              # 開始打掃（全部）
roborock pause              # 暫停
roborock stop               # 停止
roborock dock               # 回充電座
roborock status             # 查狀態
roborock map                # 看地圖
roborock rooms              # 列所有房間
roborock start --rooms <id> # 只掃指定房間
roborock consumables        # 耗材剩餘壽命
```

## 狀態說明

| 狀態 | 意思 |
|------|------|
| Charging | 充電中 |
| Idle | 待機 |
| Cleaning | 清掃中 |
| Returning Home | 回充中 |
| Paused | 暫停 |
