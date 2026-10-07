# OpenCode Session Tracker for Omarchy

A Quickshell/Omarchy bar-widget + panel to track OpenCode sessions, browse prompt history, view LLM answers, and maintain a reusable prompt library with skill shortcuts.

## Features
- Overview of prompts given over time (with timestamps)
- Session archive from OpenCode SQLite (auto-refreshed every 30s via systemd timer)
- **Answer View** - see the LLM response for any prompt, with markdown rendering, font controls, and monospace font selection
- Prompt library for preparing and reusing prompts
- Tag prompts with skills / shortcuts (#tag syntax auto-extracted)
- Day filtering (All/Today/Yesterday/7d/30d)
- Search across prompts and library
- Copy-paste into OpenCode from widget
- Export/Import library (JSON + Markdown)
- Per-session tabbing with recent prompts (50 per session)

## Views
| Shortcut | View | Description |
|----------|------|-------------|
| `Ctrl+1` | Sessions | Session tabs, prompt list, editor with answer preview |
| `Ctrl+2` | Answer | Full-width answer view with markdown, font controls |
| `Ctrl+3` | Library | Saved prompts with tags, export/import |
| `Ctrl+4` | Stats | Session/library counts |

### Sessions View (`Ctrl+1`)
- Session chips at top (click to switch)
- Day filter chips (All/Today/Yesterday/7d/30d)
- Left pane: prompt list with timestamps, searchable, day-filtered
- Right pane: editor with placeholder, Copy/Save to Library/Clear buttons
- Click any prompt → loads into editor; if answer exists, switches to Answer view

### Answer View (`Ctrl+2`)
- Full-width markdown-rendered answer
- Font family dropdown (6 monospace fonts)
- Font size slider (10-24px)
- Refresh button (re-fetches answer from cache)
- Back to Editor button (`Ctrl+E`)

### Library View (`Ctrl+3`)
- Tag chips for filtering
- Prompt list with tags, timestamps
- Editor at bottom for editing selected prompt
- Export JSON / Export Markdown / Import buttons

### Stats View (`Ctrl+4`)
- Session count, library items, recent prompt count, active session

## Shortcuts
| Key | Action |
|-----|--------|
| `Esc` | Close panel |
| `Ctrl+F` | Focus search |
| `Ctrl+W` | Clear editor |
| `Ctrl+S` | Save to Library |
| `Ctrl+E` | Back to Editor (from Answer) |
| `Ctrl+1-4` | Switch views |

## Install
```bash
omarchy plugin add https://github.com/aroehrscheid-lsrmnky/opencode-session-tracker.git --enable
```

Or manually:
```bash
git clone https://github.com/aroehrscheid-lsrmnky/opencode-session-tracker.git
cd opencode-session-tracker
./install.sh install
```

## Data Source
- Sessions: `~/.local/share/opencode/opencode.db` (SQLite) → exported to `~/.cache/opencode-sessions/sessions.json` every 30s
- Library: `~/.config/omarchy/plugins/io.github.aroehrscheid-lsrmnky.opencode-sessions/prompts.json`

## Requirements
- Omarchy (Hyprland + Quickshell)
- OpenCode CLI
- Python 3 (for exporter and scripts)
- systemd user services (for auto-refresh timer)

## License
MIT