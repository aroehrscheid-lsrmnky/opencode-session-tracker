#!/usr/bin/env python3
import json, sys, os
from datetime import datetime
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _paths
src = os.path.join(_paths.data_dir(), "prompts.json")
dst = sys.argv[1] if len(sys.argv)>1 else f"/tmp/opencode-library-{datetime.utcnow().isoformat()}.md"
if os.path.exists(src):
    with open(src) as f:
        data = json.load(f)
else:
    data = {"library":[]}
lines = ["# OpenCode Prompt Library\n"]
for item in data.get("library",[]):
    tags = " ".join(f"#{t}" for t in item.get("tags",[]))
    lines.append(f"## {item.get('id','')}\n")
    lines.append(f"**Created:** {item.get('created_at','')}\n")
    lines.append(f"{tags}\n\n")
    lines.append(f"> {item.get('text','')}\n\n")
with open(dst,"w") as f:
    f.write("\n".join(lines))
print(dst)
