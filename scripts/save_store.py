#!/usr/bin/env python3
import json, sys, os, re
from datetime import datetime
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _paths

STORE_MAP = {
    'prompt': {
        'dst_name': 'prompts.json',
        'list_key': 'library',
        'build': lambda argv: {
            'text': argv[2] if len(argv) > 2 else '',
        },
        'add': lambda data, item: data['library'].append(item)
    },
    'directive': {
        'dst_name': 'directives.json',
        'list_key': 'directives',
        'build': lambda argv: {
            'title': argv[2] if len(argv) > 2 else '',
            'text': argv[3] if len(argv) > 3 else '',
        },
        'add': lambda data, item: data['directives'].append(item)
    }
}

def main():
    if len(sys.argv) < 2:
        print('usage: save_store.py <store>', file=sys.stderr)
        sys.exit(1)
    store = sys.argv[1]
    if store not in STORE_MAP:
        sys.exit(1)
    cfg = STORE_MAP[store]
    args = cfg['build'](sys.argv)
    path = os.path.join(_paths.data_dir(), cfg['dst_name'])
    if store == 'prompt':
        if not args['text'].strip():
            sys.exit(0)
        tags = re.findall(r'#(\w+)', args['text'])
        data = {"library": []}
        if os.path.exists(path):
            try:
                with open(path) as f:
                    data = json.load(f)
            except Exception:
                data = {"library": []}
        data.setdefault('library', [])
        data['library'].append({
            'id': datetime.utcnow().isoformat(),
            'text': args['text'],
            'created_at': datetime.utcnow().isoformat(),
            'tags': tags,
            'favourite': False
        })
    elif store == 'directive':
        if not args['title'].strip() and not args['text'].strip():
            sys.exit(0)
        tags = re.findall(r'#(\w+)', args['title'] + ' ' + args['text'])
        data = {"directives": [], "selectedId": ""}
        if os.path.exists(path):
            try:
                with open(path) as f:
                    data = json.load(f)
            except Exception:
                data = {"directives": [], "selectedId": ""}
        data.setdefault('directives', [])
        data.setdefault('selectedId', '')
        data['directives'].append({
            'id': datetime.utcnow().isoformat(),
            'title': args['title'].strip() or args['text'].strip()[:40],
            'text': args['text'],
            'created_at': datetime.utcnow().isoformat(),
            'tags': tags,
        })
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as f:
        json.dump(data, f, indent=2)

if __name__ == '__main__':
    main()
