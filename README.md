# OpenCode Session Tracker for Omarchy

A Quickshell/Omarchy bar-widget + panel to track OpenCode sessions, browse prompt history, view LLM answers, and craft/refine prompts in a workbench with live send into the OpenCode TUI.

> **Full documentation: [`HANDBOOK.html`](HANDBOOK.html)** — features, per-view manual, architecture, script reference, schemas, and known limitations. This README is the short overview.

## Features
- Session archive from OpenCode SQLite (auto-refreshed via systemd timer)
- Prompt history per session with search + bookmarks
- Answer View with markdown rendering and font controls
- **Prompt workbench**: compose prompts with skill chips, key injections, and system-prompt injection
- **BODI clean-up**: refine the composed prompt via the BODI `ornith` model
- **Send**: dispatch the prompt into OpenCode — live into an `opencode --port 4096` TUI via `--attach`, with local-spawn fallback
- **Training dataset capture**: optionally record sends to `training.jsonl`, export as ShareGPT/Alpaca
- Prompt library with `#tag` extraction, export/import (JSON + Markdown)
- Skills tab: per-skill emoji/color appearance persisted to `skills.json`

## Views
| Shortcut | Tab | Description |
|----------|-----|-------------|
| `Ctrl+1` | Main ▸ Sessions | Session chips, recent prompts, workbench (compose/send) |
| `Ctrl+2` | Main ▸ Answers | Markdown answer view, navigation, font controls |
| `Ctrl+3` | Library | Editable 2-per-row prompt cards + tag filter, add/export/import |
| `Ctrl+4` | Skills | Skill list + per-skill appearance editing |
| `Ctrl+5` | Stats | Session/library/prompt counts |
| `Ctrl+6` | Dataset | Training records + ShareGPT/Alpaca export |

### Other shortcuts
| Key | Action |
|-----|--------|
| `Esc` | Close panel |
| `Ctrl+F` | Focus the prompt search |
| `Ctrl+S` | Save draft to library |
| `Ctrl+W` | Clear draft |
| `Ctrl+E` | Back to Sessions |
| `Ctrl+Return` | Send |

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
- Sessions: `~/.local/share/opencode/opencode.db` (SQLite) → exported to `~/.cache/opencode-sessions/sessions.json` by the timer
- Library: `~/.config/omarchy/plugins/io.github.aroehrscheid-lsrmnky.opencode-sessions/prompts.json`
- Send target: `http://127.0.0.1:4096` (run your TUI as `opencode --port 4096` for live delivery)

## Requirements
- Omarchy (Hyprland + Quickshell)
- OpenCode CLI
- Python 3 (exporter + panel scripts)
- systemd user services (auto-refresh timer)

## License
MIT
