#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The repository root IS the plugin (omarchy plugin add clones the repo and
# expects manifest.json at the root). Only the files below are installed; docs,
# .git and tooling stay behind.
PLUGIN_DIR_SRC="$REPO_DIR"
MANIFEST="$PLUGIN_DIR_SRC/manifest.json"

if [ ! -f "$MANIFEST" ]; then
  echo "manifest.json not found at repo root"
  exit 1
fi

PLUGIN_ID=$(python3 -c "import json; print(json.load(open('$MANIFEST'))['id'])")
PLUGIN_INSTALL_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
DATA_DIR="$HOME/.config/opencode-sessions"
CACHE_DIR="$HOME/.cache/opencode-sessions"

# Files/dirs copied into the installed plugin directory.
PLUGIN_FILES=(
  manifest.json
  BarWidget.qml
  Panel.qml
  prompts.json
  directives.json
  exporter.py
  scripts
)

migrate_store() {
  # Move a legacy user store into DATA_DIR when the target is still absent.
  local name="$1" legacy="$2"
  if [ -f "$DATA_DIR/$name" ]; then
    return
  fi
  if [ -f "$legacy" ]; then
    cp "$legacy" "$DATA_DIR/$name"
  fi
}

copy_plugin() {
  mkdir -p "$DATA_DIR"
  # User stores live OUTSIDE the plugin dir (which Omarchy watches with inotify
  # and hot-reloads on any write). Migrate any legacy copies before reseeding.
  migrate_store prompts.json "$PLUGIN_INSTALL_DIR/prompts.json"
  migrate_store directives.json "$PLUGIN_INSTALL_DIR/directives.json"
  migrate_store bookmarks.json "$CACHE_DIR/bookmarks.json"
  migrate_store skill_styles.json "$CACHE_DIR/skill_styles.json"
  migrate_store training.jsonl "$CACHE_DIR/training.jsonl"
  for entry in "${PLUGIN_FILES[@]}"; do
    src="$PLUGIN_DIR_SRC/$entry"
    [ -e "$src" ] || continue
    if [ -d "$src" ]; then
      mkdir -p "$PLUGIN_INSTALL_DIR/$entry"
      cp -r "$src"/. "$PLUGIN_INSTALL_DIR/$entry"/
    else
      cp "$src" "$PLUGIN_INSTALL_DIR/$entry"
    fi
  done
  # Seed the shipped defaults if the user has no store yet.
  for name in prompts.json directives.json; do
    [ -f "$DATA_DIR/$name" ] || cp "$PLUGIN_DIR_SRC/$name" "$DATA_DIR/$name"
  done
}

install_plugin() {
  echo "Installing $PLUGIN_ID..."
  mkdir -p "$PLUGIN_INSTALL_DIR"
  copy_plugin
  echo "Plugin installed to $PLUGIN_INSTALL_DIR"
  omarchy plugin validate "$PLUGIN_INSTALL_DIR" || true
  omarchy-shell shell rescanPlugins
  echo "Done. Open with: omarchy-shell shell summon \"$PLUGIN_ID\" '{}'"
}

update_plugin() {
  if [ ! -d "$PLUGIN_INSTALL_DIR" ]; then
    echo "Plugin not installed. Run install first."
    exit 1
  fi
  echo "Updating $PLUGIN_ID from repo..."
  copy_plugin
  echo "Plugin updated."
  omarchy-shell shell rescanPlugins
}

case "${1:-install}" in
  install) install_plugin ;;
  update) update_plugin ;;
  *) echo "Usage: $0 [install|update]"; exit 1 ;;
esac
