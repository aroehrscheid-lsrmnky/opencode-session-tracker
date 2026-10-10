#!/usr/bin/env python3
"""Report the panel's path health as JSON (used by the Settings page).

Prints one JSON object: the effective settings plus a list of checks, each with
a label, the resolved path, an ok flag and a hint. Read-only.
"""
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _paths  # noqa: E402

HOME = os.path.expanduser("~")
PLUGIN_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AGENTS_MD = os.path.join(HOME, ".config", "opencode", "AGENTS.md")
SERVICE = "opencode-sessions-exporter.service"
TIMER = "opencode-sessions-exporter.timer"


def timer_active():
    try:
        out = subprocess.run(
            ["systemctl", "--user", "is-active", TIMER],
            capture_output=True, text=True, timeout=5,
        )
        return out.stdout.strip() == "active"
    except Exception:
        return False


def check(label, path, ok, hint=""):
    return {"label": label, "path": path, "ok": bool(ok), "hint": hint}


def main():
    data = _paths.data_dir()
    cache = _paths.cache_dir()
    exporter = _paths.exporter_path()
    db = _paths.db_path()

    checks = [
        check("Plugin directory", PLUGIN_DIR, os.path.isdir(PLUGIN_DIR)),
        check("Data folder", data, os.path.isdir(data),
              "Run Repair to create it."),
        check("Cache folder", cache, os.path.isdir(cache),
              "Run Repair to create it."),
        check("Exporter", exporter, os.path.isfile(exporter),
              "Set the exporter path, or reinstall the plugin."),
        check("OpenCode database", db, os.path.isfile(db),
              "OpenCode has not created its database yet."),
        check("Export timer", TIMER, timer_active(),
              "Run Repair to install and enable it."),
        check("AGENTS.md", AGENTS_MD, os.path.isfile(AGENTS_MD),
              "Created when you save the System Prompt page."),
    ]

    report = {
        "dataDir": data,
        "cacheDir": cache,
        "exporterPath": exporter,
        "dbPath": db,
        "settingsPath": _paths.SETTINGS_PATH,
        "pluginDir": PLUGIN_DIR,
        "agentsMdPath": AGENTS_MD,
        "timerUnit": TIMER,
        "checks": checks,
        "ok": all(c["ok"] for c in checks),
    }
    print(json.dumps(report))
    return 0


if __name__ == "__main__":
    sys.exit(main())
