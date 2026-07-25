import json, pathlib, sys

root = pathlib.Path('lib/l10n')
en = json.loads((root/'app_en.arb').read_text(encoding='utf-8'))
fr = json.loads((root/'app_fr.arb').read_text(encoding='utf-8'))

fixed = False
for key, val in list(en.items()):
    if key.startswith('@') and isinstance(val, dict) and 'placeholders' in val:
        template_key = key[1:]
        fr_val = fr.get(key)
        if not isinstance(fr_val, dict):
            fr_val = {"placeholders": {}}
        for ph, meta in val['placeholders'].items():
            fr_ph_type = fr_val.get('placeholders', {}).get(ph, {}).get('type')
            if fr_ph_type is None or fr_ph_type == 'Object':
                if meta.get('type') == 'int':
                    print(f'Fixing {template_key} -> {ph} int -> Object')
                    val['placeholders'][ph]['type'] = 'Object'
                    fixed = True
                elif meta.get('type') == 'String':
                    print(f'Fixing {template_key} -> {ph} String -> Object')
                    val['placeholders'][ph]['type'] = 'Object'
                    fixed = True

if fixed:
    (root/'app_en.arb').write_text(json.dumps(en, ensure_ascii=False, indent=2), encoding='utf-8')
    print('app_en.arb updated')
else:
    print('No mismatches found')
