#!/usr/bin/env python3
import json, sys, os, re
from datetime import datetime
path = os.path.expanduser("~/.config/omarchy/plugins/io.github.aroehrscheid-lsrmnky.opencode-sessions/directives.json")
title = sys.argv[1] if len(sys.argv) > 1 else ""
text = sys.argv[2] if len(sys.argv) > 2 else ""
if not title.strip() and not text.strip():
    sys.exit(0)
tags = re.findall(r'#(\w+)', title + " " + text)
data = {"directives": [], "selectedId": ""}
if os.path.exists(path):
    try:
        with open(path) as f:
            data = json.load(f)
    except Exception:
        data = {"directives": [], "selectedId": ""}
if not isinstance(data, dict):
    data = {"directives": [], "selectedId": ""}
data.setdefault("directives", [])
data.setdefault("selectedId", "")
data["directives"].append({
    "id": datetime.utcnow().isoformat(),
    "title": title.strip() or text.strip()[:40],
    "text": text,
    "created_at": datetime.utcnow().isoformat(),
    "tags": tags,
})
with open(path, "w") as f:
    json.dump(data, f, indent=2)
