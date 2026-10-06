# Software Stack

## UI
- Quickshell QML
- Omarchy plugin system
- QtQuick, Quickshell, qs.Ui imports

## Data
- SQLite: ~/.local/share/opencode/opencode.db
- Exporter: Node.js with better-sqlite3 or Python sqlite3
- Cache: JSON in ~/.cache/opencode-sessions/
- Library: ~/.config/omarchy/plugins/<id>/prompts.json

## Tooling
- qmllint
- omarchy plugin validate
- jq
- sqlite3 CLI
