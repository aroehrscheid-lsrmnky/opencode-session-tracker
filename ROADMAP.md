# Roadmap

## Phase 1 – MVP ✅
- [x] Scaffold plugin with manifest
- [x] Bar widget showing session count
- [x] Exporter script for opencode.db → JSON (30s timer)
- [x] Panel with recent sessions list

## Phase 2 – Prompt Library ✅
- [x] Save/load prepared prompts to JSON
- [x] CRUD UI in panel
- [x] Tags, skill association, shortcuts (#tag syntax)
- [x] Export/Import JSON + Markdown

## Phase 3 – Answer View ✅
- [x] Fetch LLM answers from opencode.db
- [x] Answer View with markdown rendering
- [x] Font family dropdown (6 monospace fonts)
- [x] Font size slider (10-24px)
- [x] Refresh / Back to Editor buttons
- [x] Dual-mode right pane in Sessions (Editor ↔ Answer)

## Phase 3 – Search & UX ✅
- [x] Full-text search over sessions + library
- [x] Day filters (All/Today/Yesterday/7d/30d)
- [x] Tag filtering
- [x] Copy to clipboard
- [x] Keyboard shortcuts (Ctrl+1-4, Ctrl+E, Ctrl+F, Ctrl+S, Ctrl+W, Esc)

## Phase 5 – Prompt Workbench ✅
- [x] Skills tab: per-skill emoji/colour appearance (`skill_styles.json`)
- [x] Directives: titled, single-select standing instructions (`directives.json`) + full CRUD tab, selection shared with the Main compose pane
- [x] BODI clean-up (`✨`) via `refine_prompt.py`
- [x] Live send into OpenCode (`--attach` to `opencode --port 4096`, local-spawn fallback)
- [x] Training capture: `training.jsonl` + ShareGPT/Alpaca export
- [x] Six-tab layout with `Ctrl+1…7` shortcuts

## Phase 6 – Polish 🔄
- [ ] System Prompts tab: manage OpenCode's own standing instruction files
      (the reserved Main strip is a placeholder for this; deferred)
- [ ] Theming (light/dark variants)
- [ ] Settings UI (persist font settings)
- [ ] GitHub release workflow
- [ ] Favourite starring for prompts
- [ ] Session export/import
- [ ] Better error handling for missing answers

## Future Ideas
- [ ] Per-project session views
- [ ] Answer diff between prompts
- [ ] Skill-based prompt templates
- [ ] Webhook integration for external tools