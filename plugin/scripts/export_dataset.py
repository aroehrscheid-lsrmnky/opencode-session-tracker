#!/usr/bin/env python3
import os, json

HOME = os.path.expanduser("~")
BASE = os.path.join(HOME, ".cache", "opencode-sessions")
SRC = os.path.join(BASE, "training.jsonl")
SHARE = os.path.join(BASE, "dataset_sharegpt.json")
ALPACA = os.path.join(BASE, "dataset_alpaca.json")


def raw_request(r):
    parts = []
    skills = r.get("selected_skills") or []
    if skills:
        parts.append("Skills to use: " + ", ".join(skills))
    if (r.get("system_prompt") or "").strip():
        parts.append("System instructions:\n" + r["system_prompt"].strip())
    if (r.get("user_prompt") or "").strip():
        parts.append("Request:\n" + r["user_prompt"].strip())
    return "\n\n".join(parts)


def main():
    recs = []
    if os.path.exists(SRC):
        with open(SRC, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    recs.append(json.loads(line))
                except Exception:
                    pass

    sharegpt = []
    alpaca = []
    for r in recs:
        req = raw_request(r)
        out = (r.get("final_payload") or "").strip()
        if not req or not out:
            continue
        sharegpt.append({"conversations": [
            {"from": "human", "value": req},
            {"from": "gpt", "value": out},
        ]})
        alpaca.append({"instruction": req, "input": "", "output": out})

    with open(SHARE, "w", encoding="utf-8") as f:
        json.dump(sharegpt, f, indent=2, ensure_ascii=False)
    with open(ALPACA, "w", encoding="utf-8") as f:
        json.dump(alpaca, f, indent=2, ensure_ascii=False)

    print("Exported %d records -> %s + %s" % (len(sharegpt), os.path.basename(SHARE), os.path.basename(ALPACA)))


if __name__ == "__main__":
    main()