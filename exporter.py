#!/usr/bin/env python3
import sqlite3, json, os
from datetime import datetime

DB_PATH = os.path.expanduser("~/.local/share/opencode/opencode.db")
OUT_PATH = os.path.expanduser("~/.cache/opencode-sessions/sessions.json")

os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)

conn = sqlite3.connect(DB_PATH)
conn.row_factory = sqlite3.Row
cur = conn.cursor()

cur.execute("""
SELECT s.id, s.title, s.time_updated, p.name as project_name
FROM session s
LEFT JOIN project p ON s.project_id = p.id
ORDER BY s.time_updated DESC
LIMIT 100
""")
sessions = []
for row in cur.fetchall():
    sid = row["id"]
    cur.execute("""
    SELECT p.data, m.data, m.time_created
    FROM message m
    JOIN part p ON p.message_id = m.id
    WHERE m.session_id = ? AND json_extract(m.data,'$.role') = 'user'
    ORDER BY m.time_created DESC
    LIMIT 50
    """, (sid,))
    prompts = []
    for r in cur.fetchall():
        # extract text from part data
        try:
            import json as js
            part = js.loads(r["data"])
            text = part.get("text","")[:500]
        except:
            text = ""
        prompts.append({
            "time_created": r["time_created"],
            "prompt": text
        })
    sessions.append({
        "id": sid,
        "title": row["title"] or "Untitled",
        "project": row["project_name"] or "",
        "time_updated": row["time_updated"],
        "recent_prompts": prompts
    })

with open(OUT_PATH, "w") as f:
    json.dump({"generated_at": datetime.utcnow().isoformat(), "sessions": sessions}, f, indent=2)

print(f"Wrote {len(sessions)} sessions to {OUT_PATH}")
