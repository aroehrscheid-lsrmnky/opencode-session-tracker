#!/usr/bin/env python3
"""Resolve the panel's data/cache/db paths from the user settings file.

The settings file lives at a FIXED bootstrap location so every script and the
QML panel can find it without already knowing the configured data dir:

    ~/.config/opencode-sessions/settings.json

Recognised keys (all optional; blank/missing keys fall back to the defaults):

    dataDir       user stores (prompts.json, directives.json, training.jsonl, ...)
    cacheDir      regeneratable stores (sessions.json, skills.json, exports, ...)
    exporterPath  path to exporter.py (used by the panel only)
    dbPath        path to OpenCode's opencode.db (used by exporter.py)
"""
import json
import os

HOME = os.path.expanduser("~")
SETTINGS_PATH = os.path.join(HOME, ".config", "opencode-sessions", "settings.json")

DEFAULT_DATA_DIR = os.path.join(HOME, ".config", "opencode-sessions")
DEFAULT_CACHE_DIR = os.path.join(HOME, ".cache", "opencode-sessions")
DEFAULT_DB_PATH = os.path.join(HOME, ".local", "share", "opencode", "opencode.db")


def load_settings():
    try:
        with open(SETTINGS_PATH, encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def _path(key, default):
    val = load_settings().get(key)
    if isinstance(val, str) and val.strip():
        return os.path.expanduser(val.strip())
    return default


def data_dir():
    return _path("dataDir", DEFAULT_DATA_DIR)


def cache_dir():
    return _path("cacheDir", DEFAULT_CACHE_DIR)


def db_path():
    return _path("dbPath", DEFAULT_DB_PATH)


def exporter_path():
    # Default: exporter.py next to this scripts/ dir (the installed plugin root).
    default = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "exporter.py")
    return _path("exporterPath", default)


def settings_path():
    return SETTINGS_PATH


if __name__ == "__main__":
    import json as _json
    print(_json.dumps({
        "settings_path": settings_path(),
        "dataDir": data_dir(),
        "cacheDir": cache_dir(),
        "dbPath": db_path(),
        "exporterPath": exporter_path(),
    }, indent=2))
