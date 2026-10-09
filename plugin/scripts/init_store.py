#!/usr/bin/env python3
"""Ensure the panel's user-data stores live OUTSIDE the watched plugin dir.

Omarchy's PluginRegistry runs `inotifywait -r` over ~/.config/omarchy/plugins
and hot-reloads a plugin (closing its open panel) on any file write there. So
all user-authored state lives in ~/.config/opencode-sessions instead.

This script is idempotent and safe to run on every panel launch:
  - creates the data dir
  - migrates legacy copies (in-plugin prompts/directives, cached
    bookmarks/skill_styles/training) into it when the target is missing
  - seeds prompts/directives from the shipped plugin copies when nothing exists
"""
import os
import shutil

HOME = os.path.expanduser("~")
PLUGIN_DIR = os.path.join(
    HOME, ".config", "omarchy", "plugins",
    "io.github.aroehrscheid-lsrmnky.opencode-sessions",
)
DATA_DIR = os.path.join(HOME, ".config", "opencode-sessions")
CACHE_DIR = os.path.join(HOME, ".cache", "opencode-sessions")

# name -> ordered list of legacy sources to fall back on
MIGRATE = {
    "prompts.json": [os.path.join(PLUGIN_DIR, "prompts.json")],
    "directives.json": [os.path.join(PLUGIN_DIR, "directives.json")],
    "bookmarks.json": [os.path.join(CACHE_DIR, "bookmarks.json")],
    "skill_styles.json": [os.path.join(CACHE_DIR, "skill_styles.json")],
    "training.jsonl": [os.path.join(CACHE_DIR, "training.jsonl")],
}


def ensure(name):
    target = os.path.join(DATA_DIR, name)
    if os.path.exists(target):
        return
    for src in MIGRATE.get(name, []):
        if os.path.exists(src):
            shutil.copy2(src, target)
            return
    # Fall back to the shipped seed (read-only in the plugin dir).
    seed = os.path.join(PLUGIN_DIR, name)
    if os.path.exists(seed):
        shutil.copy2(seed, target)


def main():
    os.makedirs(DATA_DIR, exist_ok=True)
    for name in ("prompts.json", "directives.json", "bookmarks.json",
                 "skill_styles.json", "training.jsonl"):
        ensure(name)


if __name__ == "__main__":
    main()
