---
name: smart-home
description: 智慧居家統一入口，路由到正確設備：Samsung SmartThings（電視、空氣清淨機、冷氣）、Roborock 掃地機、小米家居（miiocli）、Philips Hue 燈光。使用時機：開燈、關燈、開電視、掃地、吸地板、開熱水器、智慧居家、smart home。Frame TV 換畫改用 samsung-frame-art。
---

# Smart Home

## Overview

一個入口，路由到正確設備。說什麼我就呼叫哪個工具。

## 路由表

| 你說的 | 設備 | 用哪個 |
|--------|------|--------|
| 開/關電視、切台、音量、空氣清淨機、冷氣 | Samsung | SmartThings CLI |
| 掃地、吸地板、回充、查地圖 | Roborock | roborock CLI |
| 開/關熱水器、加濕器、電鍋 | 小米 | miiocli |
| 開/關燈、調亮度、燈光情境 | Hue | openhue CLI |
| Frame TV 換畫 | Samsung Frame | → samsung-frame-art skill |

## Samsung SmartThings

```bash
source ~/.clawdbot/.env
smartthings devices                                          # 列設備
smartthings devices:capabilities $DEVICE_ID                 # 查設備能力
smartthings devices:status $DEVICE_ID                       # 查狀態
smartthings devices:commands $DEVICE_ID switch on/off       # 開關
smartthings devices:commands $TV_ID audioVolume setVolume 20
smartthings devices:commands $TV_ID mediaInputSource setInputSource HDMI1
```

## Roborock

```bash
roborock start              # 開始打掃
roborock dock               # 回充
roborock status             # 查狀態
roborock map                # 看地圖
roborock start --rooms <id> # 指定房間
roborock consumables        # 耗材剩餘
```

## 小米（miiocli）

```bash
# 開/關熱水器（智能插座）
miiocli miotdevice --ip <IP> --token <TOKEN> \
  raw_command set_properties '[{"siid":2,"piid":1,"value":true}]'

# 加濕器最大
miiocli miotdevice --ip <IP> --token <TOKEN> set_property_by 2 5 3

# 查 Token
python3 ~/.openclaw/skills/xiaomi-home/scripts/token_extractor.py
```

## Philips Hue

```bash
openhue get light --json           # 列所有燈
openhue get scene --json           # 列情境
openhue set light <name> --on
openhue set light <name> --off
openhue set light <name> --on --brightness 60
openhue set light <name> --on --rgb "#FF8800"
openhue set scene <scene-id>
```
