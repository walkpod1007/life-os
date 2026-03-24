# Health
## Smoke Tests (JSON)
```json
[
  {
    "id": "script-exists",
    "command": "test -f /Users/Modema11434/Documents/New\\ project/podcast_notebook_pipeline.py",
    "success": "exit=0",
    "tolerance": "none"
  },
  {
    "id": "sync-script-exists",
    "command": "test -f /Users/Modema11434/Documents/New\\ project/podcast_sync.py",
    "success": "exit=0",
    "tolerance": "none"
  },
  {
    "id": "venv-exists",
    "command": "test -d /Users/Modema11434/Documents/New\\ project/.venv",
    "success": "exit=0",
    "tolerance": "none"
  },
  {
    "id": "feeds-config",
    "command": "test -f /Users/Modema11434/Documents/New\\ project/inbox/podcast-feeds.json",
    "success": "exit=0",
    "tolerance": "warn"
  }
]
```
