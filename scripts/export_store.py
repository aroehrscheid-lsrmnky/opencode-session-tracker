#!/usr/bin/env python3
import json, sys, os
from datetime import datetime
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _paths

STORE_MAP = {
    'library': {
        'src_name': 'prompts.json',
        'md_title': '# OpenCode Prompt Library',
        'md_item': lambda item: {
            'tags': ' '.join(f"#{t}" for t in item.get('tags', [])),
            'id': item.get('id', ''),
            'created_at': item.get('created_at', ''),
            'text': item.get('text', '')
        }
    },
    'directives': {
        'src_name': 'directives.json',
        'md_title': '# OpenCode Directives',
        'md_item': lambda item: {
            'tags': ' '.join(f"#{t}" for t in item.get('tags', [])),
            'id': item.get('id', ''),
            'created_at': item.get('created_at', ''),
            'title': item.get('title', ''),
            'text': item.get('text', '')
        }
    }
}

def export_json(store, dst):
    cfg = STORE_MAP[store]
    src = os.path.join(_paths.data_dir(), cfg['src_name'])
    if os.path.exists(src):
        with open(src) as f:
            data = json.load(f)
    else:
        data = {cfg.get('list_key', store): []}
    with open(dst, 'w') as f:
        json.dump(data, f, indent=2)
    print(dst)

def export_md(store, dst):
    cfg = STORE_MAP[store]
    src = os.path.join(_paths.data_dir(), cfg['src_name'])
    if os.path.exists(src):
        with open(src) as f:
            data = json.load(f)
    else:
        data = {store: []}
    items = data.get(store, data.get('library', data.get('directives', [])))
    lines = [cfg['md_title'] + '\n']
    for item in items:
        d = cfg['md_item'](item)
        lines.append(f"## {d['id']}\n")
        lines.append(f"**Created:** {d['created_at']}\n")
        lines.append(f"{d['tags']}\n\n")
        if store == 'directives' and d['title']:
            lines.append(f"**{d['title']}**\n\n")
        lines.append(f"> {d['text']}\n\n")
    with open(dst, 'w') as f:
        f.write('\n'.join(lines))
    print(dst)

def main():
    if len(sys.argv) < 3:
        print('usage: export_store.py <store> <format> [dst]', file=sys.stderr)
        sys.exit(1)
    store = sys.argv[1]
    fmt = sys.argv[2]
    if store not in STORE_MAP:
        sys.exit(1)
    default = f"/tmp/opencode-{store}-{datetime.utcnow().isoformat()}.{fmt}"
    dst = sys.argv[3] if len(sys.argv) > 3 else default
    if fmt == 'json':
        export_json(store, dst)
    elif fmt == 'md':
        export_md(store, dst)
    else:
        sys.exit(1)

if __name__ == '__main__':
    main()
