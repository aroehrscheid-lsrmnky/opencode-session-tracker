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

### Sessions Tab (Ctrl+1)
- [ ] Session tabs appear at top (click to switch)
- [ ] Recent prompts list shows with day grouping
- [ ] Day chips filter: All / Today / Yesterday / 7d / 30d
- [ ] Search filters prompts in real time
- [ ] Click prompt loads text in editor
- [ ] If prompt has answer → switches to Answer view
- [ ] Copy button copies to clipboard
- [ ] Save to Library saves with tags from #tags
- [ ] Clear button clears editor

### Answer View (Ctrl+2)
- [ ] Full-width markdown-rendered answer
- [ ] Font family dropdown works (6 monospace fonts)
- [ ] Font size slider works (10-24px)
- [ ] Refresh button re-fetches answer from cache
- [ ] Back to Editor button returns to Sessions editor
- [ ] Markdown rendering: headers, lists, code blocks

### Library Tab (Ctrl+3)
- [ ] Library items load from prompts.json
- [ ] Tag chips appear and are clickable
- [ ] Clicking tag filters list
- [ ] Search filters library
- [ ] Click item loads into editor at bottom
- [ ] Export JSON creates /tmp/opencode-library-*.json
- [ ] Export MD creates /tmp/opencode-library-*.md
- [ ] Import placeholder runs

### Stats Tab (Ctrl+4)
- [ ] Sessions count displays
- [ ] Library items count displays
- [ ] Prompts in last 30d displays
- [ ] Active session name displays

### Shortcuts
- [ ] Esc closes panel
- [ ] Ctrl+F focuses search
- [ ] Ctrl+S saves to library
- [ ] Ctrl+W clears editor
- [ ] Ctrl+E returns to editor from Answer view
- [ ] Ctrl+1 Sessions, Ctrl+2 Answer, Ctrl+3 Library, Ctrl+4 Stats

## Debug
```bash
systemctl --user status opencode-sessions-exporter.timer
cat ~/.cache/opencode-sessions/sessions.json | jq '.sessions | length'
cat ~/.config/omarchy/plugins/io.github.aroehrscheid-lsrmnky.opencode-sessions/prompts.json | jq '.library | length'
```

## Visual Verification (Pixel-perfect)
```bash
# Capture all 4 views
cd /tmp/opencode
bash capture_all.sh  # Requires custom script
# Verify:
# - Sessions: left pane prompts, right pane editor, tabs blue active
# - Answer: markdown text, font controls, Back button
# - Library: tag chips, list, editor, export buttons
# - Stats: text counts
```