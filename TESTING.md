# Testing Guide

Manual test checklist for the current six-tab panel. For full feature docs see `HANDBOOK.html`.

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
# directives scripts (round-trip; the import run should add nothing new)
python3 ~/documents/opencode-session-tracker/plugin/scripts/export_directives.py
python3 ~/documents/opencode-session-tracker/plugin/scripts/import_directives.py /tmp/opencode-directives-*.json
```

## Checklist

### Main tab (Ctrl+1 Sessions / Ctrl+2 Answers)
- [ ] Session chips appear; click switches session
- [ ] Recent Prompts list populates (per active session)
- [ ] Prompt search filters in real time (Ctrl+F focuses it)
- [ ] Click prompt → Answer view; markdown renders (headers, lists, code)
- [ ] Answer navigation: Ctrl+Shift+Left/Right, font size/family controls, Refresh
- [ ] Bookmark star + bookmark filter pill work
- [ ] Right pane: a directive chip selects/deselects, the directive box edits the selected text, user prompt edits, skills chips toggle
- [ ] Search boxes live **inside** their panes (not the header): "Search skills to toggle…" in the Skills pane, "Search directives to toggle…" in the Directives pane; each filters its own chips
- [ ] Save to Library writes prompts.json with `#tags` extracted

### Send bar
- [ ] BODI Clean-up (on) refines the draft via `refine_prompt.py`
- [ ] Send runs `send_prompt.py`; status line shows `MODE: attach …` when an
      `opencode --port 4096` TUI is running, `MODE: local (…)` otherwise
- [ ] With attach: prompt appears live in the open TUI session
- [ ] Record checkbox appends a training row (Dataset tab count +1)

### Library tab (Ctrl+3)
- [ ] Cards render 2 per row; edit a card's text → border turns blue, **Save** persists to `prompts.json` (status "Prompt updated") and re-derives its `#tags`
- [ ] **Revert** restores the original text and clears the blue border
- [ ] **Delete** asks "Confirm?", a second click removes the card (auto-disarms after 4 s); the first click alone does nothing
- [ ] Bottom field: type + **Add** (or `Enter`) → status "Added to library", field clears, new card appears and survives a panel reload
- [ ] Tag chips filter the grid; empty filter shows "No library items match…"
- [ ] Clicking a card does **not** insert into the draft (use Main tab's Library chip)
- [ ] Export JSON / Export MD create `/tmp/opencode-library-*.{json,md}`
- [ ] Import merges a previously exported JSON (dedup by id)

### Directives tab (Ctrl+4)
- [ ] Cards render 2 per row with a Title field + body; edit → blue border, **Save** persists to `directives.json` and re-derives `#tags`
- [ ] **Revert** restores the original title/text and clears the blue border
- [ ] Two-step **Delete** (Confirm? → auto-disarm after 4 s); deleting the selected directive clears the selection
- [ ] **Select** radio sets the single active directive (shared with the Main tab chip row); selecting another moves it
- [ ] Bottom composer: Title + body + **Add** → status "Directive added", fields clear, card appears and survives reload
- [ ] Tag chips filter the grid; empty filter shows an empty-state message
- [ ] Export JSON / Export MD create `/tmp/opencode-directives-*.{json,md}`
- [ ] Import merges a previously exported JSON (dedup by id)

### Skills tab (Ctrl+5)
- [ ] Skills from the 4 skill dirs list with emoji/color
- [ ] Per-skill appearance editing persists to `skills.json`
- [ ] Search filters both panes

### Stats tab (Ctrl+6)
- [ ] Session/library/prompt counts display

### Dataset tab (Ctrl+7)
- [ ] Record count matches `training.jsonl`
- [ ] Export creates ShareGPT + Alpaca JSON

### Panel dismissal
- [ ] `Esc` closes panel
- [ ] Clicking the dimmed backdrop does **not** close the panel (stray miss-clicks are ignored); toggling a directive chip on the Main tab keeps it open
- [ ] The bar **OC** pill still toggles it open/closed

### Shortcuts
- [ ] `Esc` closes panel
- [ ] `Ctrl+F` focuses the prompt search (Main tab)
- [ ] `Ctrl+S` save, `Ctrl+W` clear draft, `Ctrl+E` back to Sessions
- [ ] `Ctrl+1…7` switch tabs
- [ ] `Ctrl+Return` send

## Debug
```bash
systemctl --user status opencode-sessions-exporter.timer
cat ~/.cache/opencode-sessions/sessions.json | jq '.sessions | length'
cat ~/.config/omarchy/plugins/io.github.aroehrscheid-lsrmnky.opencode-sessions/prompts.json | jq '.library | length'
cat ~/.config/omarchy/plugins/io.github.aroehrscheid-lsrmnky.opencode-sessions/directives.json | jq '.directives | length'
qs log -p "$OMARCHY_PATH/shell" --tail 100
```

## Panel shows the old UI after editing Panel.qml

`rescanPlugins` reloads the plugin and closes the panels, but the Quickshell
disk cache can keep serving the compiled component from before the edit — the
new strings never appear, no load error is logged, and no `.qmlc` is rewritten.

```bash
# what is running is stale bytecode, not the file:
grep -rl $'S\x00e\x00a\x00r\x00c\x00h\x00 \x00l\x00i\x00b' ~/.cache/quickshell/qmlcache && echo "stale"

rm -f ~/.cache/quickshell/qmlcache/*.qmlc
omarchy-restart-shell
omarchy-shell shell summon "io.github.aroehrscheid-lsrmnky.opencode-sessions" '{}'
```

After the restart the cache is rebuilt from the current file and the edit shows.
Same fix applies when a reload log line fires but the UI does not change.

## Clipboard verification
1. Open panel, select a prompt, press Copy.
2. Paste into any editor — text must match the prompt.
3. If copy fails, check Quickshell clipboard permissions.

## Visual verification
```bash
cd /tmp/opencode
bash capture_all.sh  # Requires custom script
```
