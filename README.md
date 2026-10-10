# OpenCode Session Tracker for Omarchy

A Quickshell/Omarchy bar-widget + panel to track OpenCode sessions, browse prompt history, view LLM answers, and craft/refine prompts in a workbench with live send into the OpenCode TUI.

> **Full documentation: [`HANDBOOK.html`](HANDBOOK.html)** — features, per-view manual, architecture, script reference, schemas, and known limitations. This README is the short overview.

## Features
- Session archive from OpenCode SQLite (auto-refreshed via systemd timer)
- Prompt history per session with search + bookmarks
- Answer View with markdown rendering and font controls
- **Prompt workbench**: compose prompts with skill chips and a single-select **Directives** box (persistent, titled instructions)
- **BODI clean-up**: refine the composed prompt via the BODI `ornith` model
- **Send**: dispatch the prompt into OpenCode — live into an `opencode --port 4096` TUI via `--attach`, with local-spawn fallback
- **Training dataset capture**: optionally record sends to `training.jsonl`, export as ShareGPT/Alpaca
- Prompt library with `#tag` extraction, export/import (JSON + Markdown)
- Skills tab: per-skill emoji/color appearance persisted to `skills.json`

## Views
The panel has nine tabs, jumped to with `Ctrl+1`–`Ctrl+9`.

| Shortcut | Tab | Description |
|----------|-----|-------------|
| `Ctrl+1` / `Alt+1` | Main ▸ Sessions | Session chips, recent prompts, prompt workbench (compose/send) |
| `Alt+2` | Main ▸ Answers | Markdown answer view, navigation, font controls |
| `Ctrl+2` | System Prompt | Edit OpenCode's own standing-instruction files |
| `Ctrl+3` | Skills | Per-skill emoji/colour appearance + add |
| `Ctrl+4` | Directives | Editable directive cards (title + body), select, add/export/import |
| `Ctrl+5` | Library | Editable prompt cards, tag filter, add/export/import |
| `Ctrl+6` | Stats | Session/library/prompt counts |
| `Ctrl+7` | Data | Training records + ShareGPT/Alpaca export |
| `Ctrl+8` | Settings | Data/cache/exporter/db paths, Detect, Repair |
| `Ctrl+9` | How-To | This guide |

### Other shortcuts
| Key | Action |
|-----|--------|
| `Esc` | Close panel |
| `Ctrl+F` | Focus the prompt search |
| `Ctrl+S` | Save draft to library |
| `Ctrl+W` | Clear draft |
| `Ctrl+E` | Back to Sessions |
| `Ctrl+Return` | Send |
| `Alt+1` / `Alt+2` | Sessions / Answers sub-pane (Main tab) |
| `Ctrl+Shift+Left/Right/Up` | Navigate answers |

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
- Sessions (cache): `~/.local/share/opencode/opencode.db` (SQLite) → exported to `~/.cache/opencode-sessions/sessions.json` by the timer
- User data: `~/.config/opencode-sessions/` — `prompts.json` (library), `directives.json` (`{directives:[...], selectedId}`), `bookmarks.json`, `skill_styles.json`, `training.jsonl`. Kept outside the plugin dir because Omarchy hot-reloads (and closes the panel of) any plugin whose directory is written to.
- Send target: `http://127.0.0.1:4096` (run your TUI as `opencode --port 4096` for live delivery)

## Requirements
- Omarchy (Hyprland + Quickshell)
- OpenCode CLI
- Python 3 (exporter + panel scripts)
- systemd user services (auto-refresh timer)

## License
MIT
