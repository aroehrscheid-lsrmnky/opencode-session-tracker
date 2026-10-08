#!/usr/bin/env python3
import os, re, json

HOME = os.path.expanduser("~")
OUT = os.path.join(HOME, ".cache", "opencode-sessions", "skills.json")

DIRS = [
    os.path.join(HOME, ".agents", "skills"),
    os.path.join(HOME, ".config", "opencode", "skill"),
    os.path.join(HOME, ".config", "opencode", "skills"),
    "/usr/share/omarchy/default/agents/skills",
]

BUILTINS = [
    {
        "name": "customize-opencode",
        "description": "Configure opencode itself: providers, models, agents, MCP servers, skills and permissions.",
    },
]


def parse_frontmatter(text):
    if not text.startswith("---"):
        return {}
    end = text.find("\n---", 3)
    if end == -1:
        return {}
    fm = text[3:end]
    data = {}
    key = None
    buf = []

    def flush():
        if key is not None:
            data[key] = " ".join(x.strip() for x in buf if x.strip())

    for line in fm.splitlines():
        m = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if m and not line.startswith((" ", "\t")):
            flush()
            key = m.group(1)
            val = m.group(2).strip()
            buf = [val] if val else []
        elif key is not None:
            buf.append(line)
    flush()
    return data


def main():
    skills = {}
    for b in BUILTINS:
        skills[b["name"]] = dict(b, source="builtin")

    for d in DIRS:
        if not os.path.isdir(d):
            continue
        for entry in sorted(os.listdir(d)):
            p = os.path.join(d, entry)
            sk = os.path.join(p, "SKILL.md")
            if not os.path.isdir(p) or not os.path.exists(sk):
                continue
            try:
                text = open(sk, encoding="utf-8").read()
            except Exception:
                continue
            fm = parse_frontmatter(text)
            name = fm.get("name") or entry
            if name in [s["name"] for s in BUILTINS]:
                continue
            if name in skills:
                continue
            skills[name] = {
                "name": name,
                "description": fm.get("description", ""),
                "source": p,
            }

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    ordered = BUILTINS + [skills[k] for k in sorted(skills) if k not in {b["name"] for b in BUILTINS}]
    gen = __import__("datetime").datetime.now(__import__("datetime").timezone.utc).isoformat()
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump({"generated_at": gen, "skills": ordered}, f, indent=2)
    print("wrote %d skills to %s" % (len(ordered), OUT))


if __name__ == "__main__":
    main()