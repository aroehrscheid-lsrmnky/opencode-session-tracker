#!/usr/bin/env python3
import json, sys, os, re
from datetime import datetime
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _paths
path = os.path.join(_paths.data_dir(), "prompts.json")
text = sys.argv[1] if len(sys.argv)>1 else ""
if not text.strip():
    sys.exit(0)
tags = re.findall(r'#(\w+)', text)
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
    "tags": tags,
    "favourite": False
})
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path,"w") as f:
    json.dump(data,f,indent=2)
