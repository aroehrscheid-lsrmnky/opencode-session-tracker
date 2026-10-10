#!/usr/bin/env python3
"""Create a new skill by writing a SKILL.md into the user's skills directory.

Usage:
    add_skill.py <name> [description]

Creates <skills-dir>/<name>/SKILL.md with YAML frontmatter (name, description)
followed by a short body, then re-runs the skill scan so the panel picks it up.
Refuses to overwrite an existing skill unless it only created an empty stub.
"""
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _paths

# Match the first directory list_skills.py scans, so a skill added here is
# discovered on the next scan.
SKILLS_DIR = os.path.join(os.path.expanduser("~"), ".config", "opencode", "skills")

NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")

BODY = """# {name}

{description}

## When to use

Describe the situations that should trigger this skill.

## Instructions

Describe the steps to follow.
"""


def main():
    if len(sys.argv) < 2:
        print("ERROR: skill name required", file=sys.stderr)
        return 2

    name = sys.argv[1].strip()
    desc = sys.argv[2].strip() if len(sys.argv) > 2 else ""

    if not NAME_RE.match(name):
        print("ERROR: skill name must be letters, digits, dot, dash or underscore",
              file=sys.stderr)
        return 2
    if not desc:
        desc = "Describe what this skill does."

    skill_dir = os.path.join(SKILLS_DIR, name)
    skill_md = os.path.join(skill_dir, "SKILL.md")

    if os.path.exists(skill_md):
        print("ERROR: a skill named '%s' already exists" % name, file=sys.stderr)
        return 1

    os.makedirs(skill_dir, exist_ok=True)
    with open(skill_md, "w", encoding="utf-8") as f:
        f.write("---\n")
        f.write("name: %s\n" % name)
        f.write("description: %s\n" % desc)
        f.write("---\n\n")
        f.write(BODY.format(name=name, description=desc))

    print("Created %s" % skill_md)

    scanner = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           "list_skills.py")
    subprocess.run([sys.executable, scanner], check=False)
    return 0


if __name__ == "__main__":
    sys.exit(main())