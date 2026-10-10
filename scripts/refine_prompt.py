#!/usr/bin/env python3
import sys, os, json, urllib.request, urllib.error

KEY_PATH = os.path.expanduser("~/.config/opencode/secrets/bodi-alex.key")
BASE = "https://api.code-server.de/v1"

META = (
    "You are a prompt engineer. Merge the inputs below into ONE coherent, "
    "self-contained instruction for a coding agent. Preserve every requirement "
    "and constraint. Do not invent new requirements. Output ONLY the final "
    "prompt text, with no preamble, headings, or commentary."
)


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        print("ERROR: invalid input", file=sys.stderr)
        return 2

    skills = data.get("skills", []) or []
    directive = (data.get("directive") or data.get("system") or "").strip()
    user = (data.get("user") or "").strip()
    model = data.get("model") or "ornith"

    if not skills and not directive and not user:
        print("ERROR: nothing to merge", file=sys.stderr)
        return 2

    try:
        with open(KEY_PATH, encoding="utf-8") as f:
            key = f.read().strip()
    except Exception:
        print("ERROR: cannot read BODI key file", file=sys.stderr)
        return 2

    parts = []
    if skills:
        parts.append("Skills the agent must use: " + ", ".join(skills))
    if directive:
        parts.append("Directive / standing instructions:\n" + directive)
    if user:
        parts.append("Request:\n" + user)

    body = {
        "model": model,
        "messages": [
            {"role": "system", "content": META},
            {"role": "user", "content": "\n\n".join(parts)},
        ],
        "temperature": 0.3,
    }
    req = urllib.request.Request(
        BASE + "/chat/completions",
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": "Bearer " + key,
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            obj = json.load(resp)
        out = obj["choices"][0]["message"]["content"].strip()
        print(out)
        return 0
    except urllib.error.HTTPError as e:
        print("ERROR: BODI HTTP %s" % e.code, file=sys.stderr)
        return 3
    except Exception as e:
        print("ERROR: %s" % e, file=sys.stderr)
        return 3


if __name__ == "__main__":
    sys.exit(main())