# Health
## Smoke Tests (JSON)
```json
[
  {
    "id": "yt-dlp-check",
    "command": "command -v yt-dlp",
    "success": "exit=0",
    "tolerance": "none"
  },
  {
    "id": "script-exists",
    "command": "test -f /Users/Modema11434/Documents/New\\ project/yt_notebook_pipeline.py",
    "success": "exit=0",
    "tolerance": "none"
  },
  {
    "id": "venv-exists",
    "command": "test -d /Users/Modema11434/Documents/New\\ project/.venv",
    "success": "exit=0",
    "tolerance": "none"
  }
]
```
