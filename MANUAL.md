# OpenCode Session Tracker - Manual Testing

## Prerequisites
- Omarchy with Quickshell installed
- Plugin installed at ~/.config/omarchy/plugins/io.github.aroehrscheid-lsrmnky.opencode-sessions
- Exporter timer active

## Install / Update
```bash
cd ~/documents/opencode-session-tracker
./install.sh install
# or
./install.sh update
```

## Validate
```bash
omarchy plugin validate ~/.config/omarchy/plugins/io.github.aroehrscheid-lsrmnky.opencode-sessions
```

## Open Panel
```bash
omarchy-shell shell summon "io.github.aroehrscheid-lsrmnky.opencode-sessions" '{}'
```

## Test Checklist

### Sessions Tab
- [ ] Session tabs appear at top
- [ ] Recent prompts list shows with day grouping
- [ ] Day chips filter: All / Today / Yesterday / 7d / 30d
- [ ] Search filters prompts in real time
- [ ] Click prompt loads text in editor
- [ ] Copy button copies to clipboard
- [ ] Save to Library saves with tags from #tags

### Library Tab
- [ ] Library items load from prompts.json
- [ ] Tag chips appear and are clickable
- [ ] Clicking tag filters list
- [ ] Search filters library
- [ ] Export JSON creates /tmp/opencode-library-*.json
- [ ] Export MD creates /tmp/opencode-library-*.md
- [ ] Import placeholder runs

### Stats Tab
- [ ] Sessions count displays
- [ ] Library items count displays
- [ ] Prompts in last 30d displays

### Shortcuts
- [ ] Ctrl+F focuses search
- [ ] Ctrl+S saves to library
- [ ] Ctrl+W clears editor
- [ ] Esc closes panel

## Debug
```bash
systemctl --user status opencode-sessions-exporter.timer
cat ~/.cache/opencode-sessions/sessions.json | jq '.sessions | length'
cat ~/.config/omarchy/plugins/io.github.aroehrscheid-lsrmnky.opencode-sessions/prompts.json | jq '.library | length'
```
