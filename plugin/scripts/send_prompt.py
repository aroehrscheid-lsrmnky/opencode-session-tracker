#!/usr/bin/env python3
import os, sys, json, shutil, subprocess
from datetime import datetime, timezone

HOME = os.path.expanduser("~")


def find_opencode():
    p = shutil.which("opencode")
    if p:
        return p
    for c in (
        os.path.join(HOME, ".local/share/mise/installs/opencode/latest/opencode"),
        os.path.join(HOME, ".local/share/mise/shims/opencode"),
        "/usr/local/bin/opencode",
        "/usr/bin/opencode",
    ):
        if os.path.exists(c):
            return c
    return "opencode"


def record(job, session, cwd, agent):
    try:
        rec = {
            "ts": datetime.now(timezone.utc).isoformat(),
            "session_id": session,
            "is_new_session": session is None,
            "cwd": cwd,
            "agent": agent,
            "cleanup": bool(job.get("cleanup")),
            "cleanup_model": job.get("cleanup_model", ""),
            "selected_skills": job.get("selected_skills", []),
            "system_prompt": job.get("system_prompt", ""),
            "user_prompt": job.get("user_prompt", ""),
            "raw_payload": job.get("raw_payload", ""),
            "final_payload": job.get("payload", ""),
        }
        path = os.path.join(HOME, ".cache/opencode-sessions/training.jsonl")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "a", encoding="utf-8") as f:
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")
    except Exception as e:
        print("WARN: could not record: %s" % e)


def main():
    if len(sys.argv) < 2:
        print("ERROR: job file required")
        return 2
    job = json.load(open(sys.argv[1], encoding="utf-8"))
    payload = job.get("payload", "")
    if not payload.strip():
        print("ERROR: empty payload")
        return 2

    cwd = job.get("cwd") or HOME
    if not os.path.isdir(cwd):
        cwd = HOME
    agent = job.get("agent") or "build"
    session = job.get("session_id")

    cmd = [find_opencode(), "run", "--dir", cwd, "--agent", agent]
    if session:
        cmd += ["-s", session]
    cmd += [payload]

    code = 0
    try:
        proc = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=1800)
        code = proc.returncode
        if code != 0:
            tail = (proc.stderr or proc.stdout or "").strip().splitlines()[-3:]
            print("FAILED (%d): %s" % (code, " | ".join(tail)))
        else:
            print("OK")
    except subprocess.TimeoutExpired:
        print("FAILED: timeout")
        code = 124
    except Exception as e:
        print("FAILED: %s" % e)
        code = 1

    if job.get("record"):
        record(job, session, cwd, agent)

    return code


if __name__ == "__main__":
    sys.exit(main())