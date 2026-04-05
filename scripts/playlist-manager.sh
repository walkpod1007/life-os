#!/bin/bash
# Sonos playlist manager wrapper
exec python3 "$(dirname "$0")/playlist-manager.py" "$@"
