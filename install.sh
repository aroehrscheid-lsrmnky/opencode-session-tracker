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
  # Never clobber the user's stores with the repo's seed copies.
  local backup_prompts="" backup_directives=""
  if [ -f "$PLUGIN_INSTALL_DIR/prompts.json" ]; then
    backup_prompts="$(mktemp)"
    cp "$PLUGIN_INSTALL_DIR/prompts.json" "$backup_prompts"
  fi
  if [ -f "$PLUGIN_INSTALL_DIR/directives.json" ]; then
    backup_directives="$(mktemp)"
    cp "$PLUGIN_INSTALL_DIR/directives.json" "$backup_directives"
  fi
  cp -r "$PLUGIN_DIR_SRC"/. "$PLUGIN_INSTALL_DIR"/
  if [ -n "$backup_prompts" ]; then
    mv "$backup_prompts" "$PLUGIN_INSTALL_DIR/prompts.json"
  fi
  if [ -n "$backup_directives" ]; then
    mv "$backup_directives" "$PLUGIN_INSTALL_DIR/directives.json"
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
