#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ID="io.github.yourname.opencode-sessions"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"

install_plugin() {
  echo "Installing $PLUGIN_ID..."
  mkdir -p "$PLUGIN_DIR"
  cp -r "$REPO_DIR/plugin/." "$PLUGIN_DIR/"
  echo "Plugin installed to $PLUGIN_DIR"
  omarchy plugin validate "$PLUGIN_DIR" || true
  omarchy-shell shell rescanPlugins
  echo "Done. Open with: omarchy-shell shell summon \"$PLUGIN_ID\" '{}'"
}

update_plugin() {
  echo "Updating $PLUGIN_ID from repo..."
  if [ ! -d "$PLUGIN_DIR" ]; then
    echo "Plugin not installed. Run install first."
    exit 1
  fi
  cp -r "$REPO_DIR/plugin/." "$PLUGIN_DIR/"
  echo "Plugin updated."
  omarchy-shell shell rescanPlugins
}

case "${1:-install}" in
  install) install_plugin ;;
  update) update_plugin ;;
  *) echo "Usage: $0 [install|update]"; exit 1 ;;
esac
