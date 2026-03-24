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
    "id": "auth-storage",
    "command": "test -f /Users/Modema11434/.notebooklm/storage_state.json",
    "success": "exit=0",
    "tolerance": "warn"
  },
  {
    "id": "playwright-installed",
    "command": "/Users/Modema11434/Documents/New\\ project/.venv/bin/python3 -c 'import playwright'",
    "success": "exit=0",
    "tolerance": "none"
  }
]
```
