#!/usr/bin/env python3
import json, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _paths

STORE_MAP = {
    'library': {
        'dst_name': 'prompts.json',
        'list_key': 'library'
    },
    'directives': {
        'dst_name': 'directives.json',
        'list_key': 'directives'
    }
}

def main():
    if len(sys.argv) < 3:
        print('usage: import_store.py <store> <file>', file=sys.stderr)
        sys.exit(1)
    store = sys.argv[1]
    src = sys.argv[2]
    if store not in STORE_MAP:
        sys.exit(1)
    cfg = STORE_MAP[store]
    dst = os.path.join(_paths.data_dir(), cfg['dst_name'])
    if not os.path.exists(src):
        sys.exit(1)
    with open(src) as f:
        incoming = json.load(f)
    if not isinstance(incoming, dict) or not isinstance(incoming.get(cfg['list_key']), list):
        sys.exit(1)
    existing = {cfg['list_key']: []}
    if cfg['store'] if False else True and cfg['list_key'] == 'directives':
        existing['selectedId'] = ''
    if os.path.exists(dst):
        try:
            with open(dst) as f:
                data = json.load(f)
            if isinstance(data, dict) and isinstance(data.get(cfg['list_key']), list):
                existing = data
        except Exception:
            pass
    items = existing[cfg['list_key']]
    known = {item.get('id') for item in items if isinstance(item, dict)}
    added = 0
    for item in incoming[cfg['list_key']]:
        if isinstance(item, dict) and item.get('id') not in known:
            items.append(item)
            known.add(item.get('id'))
            added += 1
    existing[cfg['list_key']] = items
    if cfg['list_key'] == 'directives':
        existing.setdefault('selectedId', '')
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with open(dst, 'w') as f:
        json.dump(existing, f, indent=2)
    if cfg['list_key'] == 'directives':
        print(f"Imported {added} new directives ({len(items)} total)")
    else:
        print(f"Imported {added} new items ({len(items)} total)")

if __name__ == '__main__':
    main()
