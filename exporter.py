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
SELECT s.id, s.title, s.time_updated, s.directory as directory, p.name as project_name
FROM session s
LEFT JOIN project p ON s.project_id = p.id
ORDER BY s.time_updated DESC
LIMIT 100
""")
sessions = []
for row in cur.fetchall():
    sid = row["id"]
    # Get all user prompts for this session, ordered by time
    cur.execute("""
    SELECT p.data, m.data, m.time_created
    FROM message m
    JOIN part p ON p.message_id = m.id
    WHERE m.session_id = ? AND json_extract(m.data,'$.role') = 'user'
    ORDER BY m.time_created ASC
    LIMIT 50
    """, (sid,))
    user_rows = cur.fetchall()
    
    prompts = []
    for i, r in enumerate(user_rows):
        # extract text from part data
        try:
            part = json.loads(r["data"])
            text = part.get("text","")[:500]
        except:
            text = ""
        
        prompt_time = r["time_created"]
        # Find next user prompt time for boundary
        next_prompt_time = user_rows[i+1]["time_created"] if i+1 < len(user_rows) else None
        
        # Get last assistant answer between this prompt and next prompt
        answer = None
        if next_prompt_time:
            cur.execute("""
            SELECT p.data
            FROM message m
            JOIN part p ON p.message_id = m.id
            WHERE m.session_id = ? 
              AND json_extract(m.data,'$.role') = 'assistant'
              AND m.time_created > ?
              AND m.time_created < ?
              AND json_extract(p.data,'$.type') = 'text'
            ORDER BY m.time_created DESC
            LIMIT 1
            """, (sid, prompt_time, next_prompt_time))
        else:
            cur.execute("""
            SELECT p.data
            FROM message m
            JOIN part p ON p.message_id = m.id
            WHERE m.session_id = ? 
              AND json_extract(m.data,'$.role') = 'assistant'
              AND m.time_created > ?
              AND json_extract(p.data,'$.type') = 'text'
            ORDER BY m.time_created DESC
            LIMIT 1
            """, (sid, prompt_time))
        
        ans_row = cur.fetchone()
        if ans_row:
            try:
                ans_part = json.loads(ans_row["data"])
                answer = ans_part.get("text", "")
            except:
                answer = ""
        
        prompts.append({
            "time_created": prompt_time,
            "prompt": text,
            "answer": answer
        })
    
    sessions.append({
        "id": sid,
        "title": row["title"] or "Untitled",
        "project": row["project_name"] or "",
        "cwd": row["directory"] or os.path.expanduser("~"),
        "time_updated": row["time_updated"],
        "recent_prompts": prompts
    })

with open(OUT_PATH, "w") as f:
    json.dump({"generated_at": datetime.utcnow().isoformat(), "sessions": sessions}, f, indent=2)

print(f"Wrote {len(sessions)} sessions to {OUT_PATH}")