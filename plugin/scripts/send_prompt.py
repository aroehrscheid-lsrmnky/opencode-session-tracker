#!/usr/bin/env python3
import os, re, sys, json, shutil, subprocess, urllib.request
from datetime import datetime, timezone

HOME = os.path.expanduser("~")
ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
DEFAULT_ATTACH = "http://127.0.0.1:4096"


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


def probe_server(url, cwd):
    """A running opencode server (TUI started with --port, or `opencode serve`)
    that is healthy AND serving the same project directory as this job.
    Sending through it delivers the message to every attached client live
    (the open TUI updates immediately); a plain local `run` only shares the
    SQLite file, so the TUI would not see it without a session refetch."""
    base = url.rstrip("/")
    try:
        with urllib.request.urlopen(base + "/global/health", timeout=2) as r:
            if r.status != 200:
                return False, "health HTTP %d" % r.status
            body = json.load(r)
        if isinstance(body, dict) and body.get("healthy") is False:
            return False, "server unhealthy"
    except Exception as e:
        return False, "no server at %s (%s)" % (base, e)
    try:
        with urllib.request.urlopen(base + "/path", timeout=2) as r:
            p = json.load(r)
        server_path = p.get("directory") or p.get("path") if isinstance(p, dict) else None
        if server_path and os.path.realpath(server_path) != os.path.realpath(cwd):
            return False, "project mismatch (%s != %s)" % (server_path, cwd)
    except Exception:
        pass  # /path unreadable: health is enough, let `run` judge the session
    return True, "ok"


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
            "directive": job.get("directive", ""),
            "directive_id": job.get("directive_id", ""),
            "directive_title": job.get("directive_title", ""),
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

    # Attach policy: job["attach"] False -> force local; str -> that URL;
    # unset -> OPENCODE_ATTACH_URL env or default port, probed for health.
    attach_opt = job.get("attach")
    if attach_opt is False:
        server, mode = None, "local (attach disabled)"
    else:
        server = attach_opt or os.environ.get("OPENCODE_ATTACH_URL") or DEFAULT_ATTACH
        ok, why = probe_server(server, cwd)
        if ok:
            mode = "attach %s" % server
        else:
            server, mode = None, "local (%s)" % why

    cmd = [find_opencode(), "run", "--dir", cwd, "--agent", agent]
    if session:
        cmd += ["-s", session]
    if server:
        cmd += ["--attach", server]
    cmd += [payload]
    print("MODE: %s" % mode, flush=True)

    code = 0
    try:
        # stdin must be DEVNULL: `opencode run` reads stdin to EOF when it is
        # not a TTY, and quickshell's process pipe never delivers EOF -> hang.
        proc = subprocess.Popen(
            cmd,
            cwd=cwd,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )
        lines = []
        deadline = datetime.now(timezone.utc).timestamp() + 1800
        try:
            for line in proc.stdout:
                line = ANSI.sub("", line).rstrip("\n").strip()
                if not line:
                    continue
                lines.append(line)
                print(line, flush=True)
                if datetime.now(timezone.utc).timestamp() > deadline:
                    proc.kill()
                    raise subprocess.TimeoutExpired(cmd, 1800)
        except subprocess.TimeoutExpired:
            proc.wait()
            print("FAILED: timeout")
            code = 124
        proc.wait(timeout=30)
        code = code or proc.returncode
        if code != 0:
            tail = [l for l in lines[-6:] if l.strip()]
            if not lines:
                tail = ["no output"]
            print("FAILED (%d): %s" % (code, " | ".join(tail)))
        elif not any(l.strip() for l in lines):
            print("OK (no output)")
        else:
            print("OK")
    except Exception as e:
        print("FAILED: %s" % e)
        code = 1

    if job.get("record"):
        record(job, session, cwd, agent)

    return code


if __name__ == "__main__":
    sys.exit(main())
