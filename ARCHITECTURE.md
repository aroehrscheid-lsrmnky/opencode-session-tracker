# Architecture

## Components
1. **Exporter Bridge**
   - Reads opencode.db
   - Outputs sessions.json
   - Runs via systemd user timer every 30s

2. **BarWidget.qml**
   - Shows pill with count / last activity
   - Click opens Panel

3. **Panel.qml**
   - Tabs: Recent, Library, Search
   - Loads JSON cache

4. **Library Store**
   - prompts.json with id, text, tags, skill, created

## Data Flow
OpenCode DB → Exporter → JSON cache → QML Panel → User edits → prompts.json
