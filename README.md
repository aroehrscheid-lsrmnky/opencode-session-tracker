# OpenCode Session Tracker for Omarchy

A Quickshell/Omarchy bar-widget + panel to track OpenCode sessions, browse prompt history, and maintain a reusable prompt library with skill shortcuts.

## Features
- Overview of prompts given over time
- Session archive from OpenCode SQLite
- Prompt library for preparing prompts later
- Tag prompts with skills / shortcuts
- Copy-paste into OpenCode from widget

## Install
```bash
omarchy plugin add https://github.com/yourname/opencode-session-tracker.git --enable
```

## Docs
- ROADMAP.md
- ARCHITECTURE.md
- DESIGN.md
- SOFTWARE_STACK.md

## Progress
Current commit: $(git -C /home/remotemonkey/documents/opencode-session-tracker rev-parse --short HEAD)
Last update: $(date -u +"%Y-%m-%d %H:%M UTC")
57a82e3 Add install.sh with install and update functions