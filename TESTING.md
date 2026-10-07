# Testing Guide

## Prerequisites
- Omarchy installed
- Plugin files in ~/.config/omarchy/plugins/io.github.aroehrscheid-lsrmnky.opencode-sessions/
- Exporter timer active

## Quick smoke test
```bash
python3 ~/documents/opencode-session-tracker/exporter.py
cat ~/.cache/opencode-sessions/sessions.json | jq '.sessions | length'
```

## Install plugin
```bash
mkdir -p ~/.config/omarchy/plugins/io.github.aroehrscheid-lsrmnky.opencode-sessions
cp -r ~/documents/opencode-session-tracker/plugin/* ~/.config/omarchy/plugins/io.github.aroehrscheid-lsrmnky.opencode-sessions/
omarchy plugin validate ~/.config/omarchy/plugins/io.github.aroehrscheid-lsrmnky.opencode-sessions
omarchy-shell shell rescanPlugins
```

## Open panel
```bash
omarchy-shell shell summon "io.github.aroehrscheid-lsrmnky.opencode-sessions" '{}'
```

## Test flows

### Sessions Tab (Ctrl+1)
1. Session tabs appear at top, click to switch
2. Day chips filter: All / Today / Yesterday / 7d / 30d
3. Search filters prompts in real time
4. Click prompt → loads text in editor
5. If prompt has answer → switches to Answer view (Ctrl+2)
6. Copy button → clipboard
7. Save to Library → saves with #tags
8. Clear button → clears editor

### Answer View (Ctrl+2)
1. Full-width markdown-rendered answer displays
2. Font family dropdown works (JetBrains Mono, Fira Code, Source Code Pro, Cascadia Code, IBM Plex Mono, Monospace)
2. Font size slider works (10-24px)
3. Refresh button re-fetches answer from cache
4. Back to Editor button returns to Sessions editor
5. Markdown rendering: headers, lists, code blocks, inline code

### Library Tab (Ctrl+3)
1. Library items load from prompts.json
2. Tag chips appear and are clickable (filter)
3. Search filters library
4. Click item → loads into editor at bottom
5. Export JSON → /tmp/opencode-library-*.json
6. Export MD → /tmp/opencode-library-*.md
7. Import placeholder runs

### Stats Tab (Ctrl+4)
1. Sessions count displays
2. Library items count displays
3. Prompts in last 30d displays
4. Active session name displays

### Shortcuts
- Esc → closes panel
- Ctrl+F → focuses search
- Ctrl+S → saves to library
- Ctrl+W → clears editor
- Ctrl+E → back to editor from Answer view
- Ctrl+1 → Sessions, Ctrl+2 → Answer, Ctrl+3 → Library, Ctrl+4 → Stats

## Debug
```bash
systemctl --user status opencode-sessions-exporter.timer
qs log -p "$OMARCHY_PATH/shell" --tail 100
```

## Clipboard verification
1. Open panel, select a prompt, press Copy.
2. Open any text editor and paste Ctrl+V.
3. Ensure text matches prompt.

If copy fails, check Quickshell clipboard permissions.

## Visual verification (pixel-perfect)
```bash
cd /tmp/opencode
bash capture_all.sh
# Verify:
# - Sessions: left pane prompts, right pane editor, blue active tab
# - Answer: markdown text, font controls, Back button
# - Library: tag chips, list, editor, export buttons
# - Stats: text counts
```