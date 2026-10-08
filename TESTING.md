# Testing Guide

Manual test checklist for the current five-tab panel. For full feature docs see `HANDBOOK.html`.

## Prerequisites
- Omarchy (Hyprland + Quickshell)
- Plugin installed at `~/.config/omarchy/plugins/io.github.aroehrscheid-lsrmnky.opencode-sessions`
- Exporter timer active

## Install / Update
```bash
cd ~/documents/opencode-session-tracker
./install.sh install   # or: ./install.sh update
omarchy plugin validate ~/.config/omarchy/plugins/io.github.aroehrscheid-lsrmnky.opencode-sessions
```

## Open panel
```bash
omarchy-shell shell summon "io.github.aroehrscheid-lsrmnky.opencode-sessions" '{}'
```

## Quick smoke test
```bash
python3 ~/documents/opencode-session-tracker/exporter.py
cat ~/.cache/opencode-sessions/sessions.json | jq '.sessions | length'
```

## Checklist

### Main tab (Ctrl+1 Sessions / Ctrl+2 Answers)
- [ ] Session chips appear; click switches session
- [ ] Recent Prompts list populates (per active session)
- [ ] Prompt search filters in real time (Ctrl+F focuses it)
- [ ] Click prompt → Answer view; markdown renders (headers, lists, code)
- [ ] Answer navigation: Ctrl+Shift+Left/Right, font size/family controls, Refresh
- [ ] Bookmark star + bookmark filter pill work
- [ ] Right pane: key injections insert, system/user prompt edit, skills chips toggle
- [ ] Save to Library writes prompts.json with `#tags` extracted

### Send bar
- [ ] BODI Clean-up (on) refines the draft via `refine_prompt.py`
- [ ] Send runs `send_prompt.py`; status line shows `MODE: attach …` when an
      `opencode --port 4096` TUI is running, `MODE: local (…)` otherwise
- [ ] With attach: prompt appears live in the open TUI session
- [ ] Record checkbox appends a training row (Dataset tab count +1)

### Library tab (Ctrl+3)
- [ ] Items list; tag chips filter; search filters (items are display-only)
- [ ] Export JSON / Export MD create `/tmp/opencode-library-*.{json,md}`
- [ ] Import merges a previously exported JSON (dedup by id)

### Skills tab (Ctrl+4)
- [ ] Skills from the 4 skill dirs list with emoji/color
- [ ] Per-skill appearance editing persists to `skills.json`
- [ ] Search filters both panes

### Stats tab (Ctrl+5)
- [ ] Session/library/prompt counts display

### Dataset tab (Ctrl+6)
- [ ] Record count matches `training.jsonl`
- [ ] Export creates ShareGPT + Alpaca JSON

### Shortcuts
- [ ] `Esc` closes panel
- [ ] `Ctrl+F` focuses search (Main: prompt search, Library: library search)
- [ ] `Ctrl+S` save, `Ctrl+W` clear draft, `Ctrl+E` back to Sessions
- [ ] `Ctrl+1…6` switch tabs
- [ ] `Ctrl+Return` send

## Debug
```bash
systemctl --user status opencode-sessions-exporter.timer
cat ~/.cache/opencode-sessions/sessions.json | jq '.sessions | length'
cat ~/.config/omarchy/plugins/io.github.aroehrscheid-lsrmnky.opencode-sessions/prompts.json | jq '.library | length'
qs log -p "$OMARCHY_PATH/shell" --tail 100
```

## Clipboard verification
1. Open panel, select a prompt, press Copy.
2. Paste into any editor — text must match the prompt.
3. If copy fails, check Quickshell clipboard permissions.

## Visual verification
```bash
cd /tmp/opencode
bash capture_all.sh  # Requires custom script
```
