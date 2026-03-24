---
title: "HEALTH"
created: 2026-03-23
tags: [system]
---

# Health
## Smoke Tests (JSON)
```json
[
  {
    "id": "notebooklm-cli",
    "command": "test -f /Users/Modema11434/Documents/New\\ project/.venv/bin/notebooklm",
    "success": "exit=0",
    "tolerance": "none"
  },
  {
    "id": "vault-writable",
    "command": "test -w /Users/Modema11434/Library/Mobile\\ Documents/iCloud~md~obsidian/Documents/Obsidian\\ Vault/30_Knowledge/",
    "success": "exit=0",
    "tolerance": "none"
  }
]
```
