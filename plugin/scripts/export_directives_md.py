#!/usr/bin/env python3
import json, sys, os
from datetime import datetime
src = os.path.expanduser("~/.config/opencode-sessions/directives.json")
dst = sys.argv[1] if len(sys.argv)>1 else f"/tmp/opencode-directives-{datetime.utcnow().isoformat()}.md"
if os.path.exists(src):
    with open(src) as f:
        data = json.load(f)
else:
    data = {"directives":[], "selectedId":""}
lines = ["# OpenCode Directives\n"]
for item in data.get("directives",[]):
    tags = " ".join(f"#{t}" for t in item.get("tags",[]))
    lines.append(f"## {item.get('title','')}\n")
    lines.append(f"**Created:** {item.get('created_at','')}\n")
    lines.append(f"{tags}\n\n")
    lines.append(f"> {item.get('text','')}\n\n")
with open(dst,"w") as f:
    f.write("\n".join(lines))
print(dst)
