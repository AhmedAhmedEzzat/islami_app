"""Adds keys to both ARB files. Usage: python3 tool/add_l10n.py < entries.json

entries.json: [[key, english, arabic, {placeholders...} | null], ...]
An existing key is overwritten, so this can also correct wording."""
import collections, json, sys

entries = json.load(sys.stdin)
for path, col in (('lib/l10n/app_en.arb', 1), ('lib/l10n/app_ar.arb', 2)):
    d = json.load(open(path, encoding='utf-8'), object_pairs_hook=collections.OrderedDict)
    for e in entries:
        key = e[0]
        d[key] = e[col]
        if col == 1 and len(e) > 3 and e[3]:
            d['@' + key] = {'placeholders': e[3]}
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(d, f, ensure_ascii=False, indent=2)
        f.write('\n')
print(f'{len(entries)} keys written')
