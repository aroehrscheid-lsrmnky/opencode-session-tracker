#!/usr/bin/env python3
"""Persist panel settings and migrate user stores when a folder changes.

Usage:
    save_settings.py '<json-object>'

The JSON object holds the settings to merge into
~/.config/opencode-sessions/settings.json. Recognised keys: dataDir, cacheDir,
exporterPath, dbPath (plus optional font keys). A blank/None value removes the
key so the built-in default applies.

When dataDir or cacheDir changes, existing store files are copied from the old
location to the new one (never overwriting), so a relocation keeps your data.
"""
import json
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _paths  # noqa: E402

ALLOWED = {"dataDir", "cacheDir", "exporterPath", "dbPath",
           "answerFontFamily", "answerFontSize"}
DATA_STORES = ("prompts.json", "directives.json", "bookmarks.json",
               "skill_styles.json", "training.jsonl")
CACHE_STORES = ("sessions.json", "skills.json", "send_job.json",
                "dataset_sharegpt.json", "dataset_alpaca.json")


def load():
    try:
        with open(_paths.SETTINGS_PATH) as f:
            d = json.load(f)
        return d if isinstance(d, dict) else {}
    except (OSError, ValueError):
        return {}


def migrate(src_dir, dst_dir, names):
    """Copy store files from src to dst when dst is missing them."""
    if not src_dir or not dst_dir:
        return 0
    if os.path.realpath(src_dir) == os.path.realpath(dst_dir):
        return 0
    if not os.path.isdir(src_dir):
        return 0
    os.makedirs(dst_dir, exist_ok=True)
    moved = 0
    for name in names:
        src = os.path.join(src_dir, name)
        dst = os.path.join(dst_dir, name)
        if os.path.exists(src) and not os.path.exists(dst):
            try:
                shutil.copy2(src, dst)
                moved += 1
            except OSError:
                pass
    return moved


def main():
    if len(sys.argv) < 2:
        print("ERROR: json object required", file=sys.stderr)
        return 2
    try:
        changes = json.loads(sys.argv[1])
    except ValueError as e:
        print("ERROR: bad json: %s" % e, file=sys.stderr)
        return 2
    if not isinstance(changes, dict):
        print("ERROR: expected a json object", file=sys.stderr)
        return 2

    current = load()
    old_data = current.get("dataDir") or _paths.DEFAULT_DATA_DIR
    old_cache = current.get("cacheDir") or _paths.DEFAULT_CACHE_DIR

    for k, v in changes.items():
        if k not in ALLOWED:
            continue
        if v is None or (isinstance(v, str) and not v.strip()):
            current.pop(k, None)
        else:
            current[k] = os.path.expanduser(v) if isinstance(v, str) else v

    os.makedirs(os.path.dirname(_paths.SETTINGS_PATH), exist_ok=True)
    tmp = _paths.SETTINGS_PATH + ".tmp"
    with open(tmp, "w") as f:
        json.dump(current, f, indent=2)
    os.replace(tmp, _paths.SETTINGS_PATH)

    new_data = current.get("dataDir") or _paths.DEFAULT_DATA_DIR
    new_cache = current.get("cacheDir") or _paths.DEFAULT_CACHE_DIR
    moved = migrate(old_data, new_data, DATA_STORES)
    moved += migrate(old_cache, new_cache, CACHE_STORES)

    print("Saved settings (%d store files migrated)" % moved)
    return 0


if __name__ == "__main__":
    sys.exit(main())
