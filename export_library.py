#!/usr/bin/env python3
import json, sys, os
from datetime import datetime
src = os.path.expanduser("~/.config/omarchy/plugins/io.github.yourname.opencode-sessions/prompts.json")
dst = sys.argv[1] if len(sys.argv)>1 else f"/tmp/opencode-library-{datetime.utcnow().isoformat()}.json"
if os.path.exists(src):
    with open(src) as f:
        data = json.load(f)
else:
    data = {"library":[]}
with open(dst,"w") as f:
    json.dump(data,f,indent=2)
print(dst)
