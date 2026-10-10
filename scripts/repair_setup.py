#!/usr/bin/env python3
"""Create missing folders, seed stores and (re)install the export timer.

The "Repair" action behind the Settings page. Idempotent; prints one status
line per step. Uses the exporter path resolved from settings so the timer points
at wherever exporter.py actually lives.
"""
import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _paths  # noqa: E402

PLUGIN_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SYSTEMD_DIR = os.path.join(os.path.expanduser("~"), ".config", "systemd", "user")
SERVICE_PATH = os.path.join(SYSTEMD_DIR, "opencode-sessions-exporter.service")
TIMER_PATH = os.path.join(SYSTEMD_DIR, "opencode-sessions-exporter.timer")

SERVICE_TMPL = """[Unit]
Description=Export OpenCode sessions to JSON for Omarchy widget

[Service]
Type=oneshot
ExecStart=/usr/bin/python3 {exporter}
"""

TIMER_TMPL = """[Unit]
Description=Run OpenCode sessions exporter every 30 seconds

[Timer]
OnBootSec=10sec
OnUnitActiveSec=30sec

[Install]
WantedBy=timers.target
"""


def run(cmd):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
        return r.returncode == 0, (r.stderr or r.stdout or "").strip()
    except Exception as e:
        return False, str(e)


def main():
    data = _paths.data_dir()
    cache = _paths.cache_dir()
    exporter = _paths.exporter_path()

    os.makedirs(data, exist_ok=True)
    os.makedirs(cache, exist_ok=True)
    print("Folders ready: %s, %s" % (data, cache))

    # Seed shipped defaults if the user has no store yet.
    for name in ("prompts.json", "directives.json"):
        target = os.path.join(data, name)
        seed = os.path.join(PLUGIN_DIR, name)
        if not os.path.exists(target) and os.path.exists(seed):
            shutil.copy2(seed, target)
            print("Seeded %s" % name)

    if not os.path.isfile(exporter):
        print("ERROR: exporter not found at %s" % exporter)
        print("Set the exporter path in Settings, then Repair again.")
        return 1

    os.makedirs(SYSTEMD_DIR, exist_ok=True)
    with open(SERVICE_PATH, "w") as f:
        f.write(SERVICE_TMPL.format(exporter=exporter))
    with open(TIMER_PATH, "w") as f:
        f.write(TIMER_TMPL)
    print("Wrote systemd units pointing at %s" % exporter)

    run(["systemctl", "--user", "daemon-reload"])
    ok, msg = run(["systemctl", "--user", "enable", "--now",
                   "opencode-sessions-exporter.timer"])
    print("Timer enabled" if ok else "Timer enable failed: %s" % msg)
    ok2, _ = run(["systemctl", "--user", "restart", "opencode-sessions-exporter.timer"])
    if not ok2:
        print("WARN: could not restart timer")
    return 0


if __name__ == "__main__":
    sys.exit(main())
