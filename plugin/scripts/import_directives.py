#!/usr/bin/env python3
import json, sys, os
src = sys.argv[1]
dst = os.path.expanduser("~/.config/omarchy/plugins/io.github.aroehrscheid-lsrmnky.opencode-sessions/directives.json")
if not os.path.exists(src):
    sys.exit(1)
with open(src) as f:
    incoming = json.load(f)
if not isinstance(incoming, dict) or not isinstance(incoming.get("directives"), list):
    sys.exit(1)
existing = {"directives": [], "selectedId": ""}
if os.path.exists(dst):
    try:
        with open(dst) as f:
            data = json.load(f)
        if isinstance(data, dict) and isinstance(data.get("directives"), list):
            existing = data
    except (json.JSONDecodeError, OSError):
        pass
existing.setdefault("selectedId", "")
directives = existing["directives"]
known = {item.get("id") for item in directives if isinstance(item, dict)}
added = 0
for item in incoming["directives"]:
    if isinstance(item, dict) and item.get("id") not in known:
        directives.append(item)
        known.add(item.get("id"))
        added += 1
existing["directives"] = directives
with open(dst, "w") as f:
    json.dump(existing, f, indent=2)
print(f"Imported {added} new directives ({len(directives)} total)")
