#!/usr/bin/env python3
import json, sys, os
from datetime import datetime
path = os.path.expanduser("~/.config/omarchy/plugins/io.github.yourname.opencode-sessions/prompts.json")
text = sys.argv[1] if len(sys.argv)>1 else ""
tags = sys.argv[2] if len(sys.argv)>2 else ""
if not text.strip():
    sys.exit(0)
if os.path.exists(path):
    with open(path) as f:
        data = json.load(f)
else:
    data = {"library":[]}
data.setdefault("library",[])
data["library"].append({
    "id": datetime.utcnow().isoformat(),
    "text": text,
    "created_at": datetime.utcnow().isoformat(),
    "tags": [t.strip() for t in tags.split(",") if t.strip()]
})
with open(path,"w") as f:
    json.dump(data,f,indent=2)
