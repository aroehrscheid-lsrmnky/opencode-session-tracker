#!/usr/bin/env python3
import json, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _paths
src = sys.argv[1]
dst = os.path.join(_paths.data_dir(), "prompts.json")
if not os.path.exists(src):
    sys.exit(1)
with open(src) as f:
    incoming = json.load(f)
if not isinstance(incoming, dict) or not isinstance(incoming.get("library"), list):
    sys.exit(1)
existing = {"library": []}
if os.path.exists(dst):
    try:
        with open(dst) as f:
            data = json.load(f)
        if isinstance(data, dict) and isinstance(data.get("library"), list):
            existing = data
    except (json.JSONDecodeError, OSError):
        pass
lib = existing["library"]
known = {item.get("id") for item in lib if isinstance(item, dict)}
added = 0
for item in incoming["library"]:
    if isinstance(item, dict) and item.get("id") not in known:
        lib.append(item)
        known.add(item.get("id"))
        added += 1
existing["library"] = lib
os.makedirs(os.path.dirname(dst), exist_ok=True)
with open(dst, "w") as f:
    json.dump(existing, f, indent=2)
print(f"Imported {added} new items ({len(lib)} total)")
