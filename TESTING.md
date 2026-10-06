# Testing Guide

## Prerequisites
- Omarchy installed
- Plugin files in ~/.config/omarchy/plugins/io.github.yourname.opencode-sessions/
- Exporter timer active

## Quick smoke test
```bash
python3 ~/documents/opencode-session-tracker/exporter.py
cat ~/.cache/opencode-sessions/sessions.json | jq '.sessions | length'
```

## Install plugin
```bash
mkdir -p ~/.config/omarchy/plugins/io.github.yourname.opencode-sessions
cp -r ~/documents/opencode-session-tracker/plugin/* ~/.config/omarchy/plugins/io.github.yourname.opencode-sessions/
omarchy plugin validate ~/.config/omarchy/plugins/io.github.yourname.opencode-sessions
omarchy-shell shell rescanPlugins
```

## Open panel
```bash
omarchy-shell shell summon "io.github.yourname.opencode-sessions" '{}'
```

## Test flows
1. Sessions tab: check tabs, day chips filter list
2. Click prompt -> editor fills
3. Copy button works
4. Save to Library -> check prompts.json
5. Library tab -> tag chips clickable
6. Stats tab -> numbers display
7. Shortcuts: Ctrl+F, Ctrl+S, Ctrl+W, Esc

## Debug
```bash
systemctl --user status opencode-sessions-exporter.timer
qs log -p "$OMARCHY_PATH/shell" --tail 100
```
