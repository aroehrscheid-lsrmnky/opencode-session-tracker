#!/usr/bin/env python3
"""List the files OpenCode merges as standing instructions; print JSON.

Sources:
  - global:  ~/.config/opencode/AGENTS.md
  - instructions[] entries from ~/.config/opencode/opencode.json
  - per-agent prompts: ~/.config/opencode/agent/*.md
  - project: <cwd>/AGENTS.md when a cwd argument is given

Each item: {"label", "path", "kind", "exists"}.
"""
import glob
import json
import os
import sys

HOME = os.path.expanduser("~")
OPENCODE_DIR = os.path.join(HOME, ".config", "opencode")
AGENTS_MD = os.path.join(OPENCODE_DIR, "AGENTS.md")
CONFIG_JSON = os.path.join(OPENCODE_DIR, "opencode.json")


def expand(p):
    return os.path.expanduser(p) if isinstance(p, str) else p


def main():
    sources = []
    seen = set()

    def add(label, path, kind, require_exists=False):
        if not path:
            return
        path = expand(path)
        if path in seen:
            return
        exists = os.path.isfile(path)
        if require_exists and not exists:
            return
        seen.add(path)
        sources.append({"label": label, "path": path, "kind": kind, "exists": exists})

    add("Global AGENTS.md", AGENTS_MD, "global")

    try:
        with open(CONFIG_JSON) as f:
            cfg = json.load(f)
    except (OSError, ValueError):
        cfg = {}
    for i, entry in enumerate(cfg.get("instructions", []) or []):
        add("instructions[%d]" % i, entry, "config", require_exists=True)

    for p in sorted(glob.glob(os.path.join(OPENCODE_DIR, "agent", "*.md"))):
        add("agent/" + os.path.basename(p), p, "agent", require_exists=True)

    if len(sys.argv) > 1 and sys.argv[1]:
        cwd = os.path.expanduser(sys.argv[1])
        add("project AGENTS.md", os.path.join(cwd, "AGENTS.md"), "project")

    print(json.dumps({"sources": sources}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
