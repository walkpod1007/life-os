#!/bin/bash
ulimit -n 65536
exec /opt/homebrew/bin/bun webhook.ts
