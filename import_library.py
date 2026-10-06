#!/usr/bin/env python3
import json, sys, os
src = sys.argv[1]
dst = os.path.expanduser("~/.config/omarchy/plugins/io.github.aroehrscheid-lsrmnky.opencode-sessions/prompts.json")
if not os.path.exists(src):
    sys.exit(1)
with open(src) as f:
    data = json.load(f)
with open(dst,"w") as f:
    json.dump(data,f,indent=2)
print("imported")
