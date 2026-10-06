#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR_SRC="$REPO_DIR/plugin"
MANIFEST="$PLUGIN_DIR_SRC/manifest.json"

if [ ! -f "$MANIFEST" ]; then
  echo "manifest.json not found in plugin/"
  exit 1
fi

PLUGIN_ID=$(python3 -c "import json; print(json.load(open('$MANIFEST'))['id'])")
PLUGIN_INSTALL_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"

copy_plugin() {
  # Never clobber the user's prompt library with the repo's empty seed copy.
  local backup=""
  if [ -f "$PLUGIN_INSTALL_DIR/prompts.json" ]; then
    backup="$(mktemp)"
    cp "$PLUGIN_INSTALL_DIR/prompts.json" "$backup"
  fi
  cp -r "$PLUGIN_DIR_SRC"/. "$PLUGIN_INSTALL_DIR"/
  if [ -n "$backup" ]; then
    mv "$backup" "$PLUGIN_INSTALL_DIR/prompts.json"
  fi
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
