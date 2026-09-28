"""Refresh browser fixtures from shared Lua. Requires Python + lupa (Lua 5.4).

Game-dependent hair/texture counts below are representative preview values;
FiveM always queries its actual loaded model. Run from the repository root.
"""
import json
from pathlib import Path
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
root = 'server-data/resources/[custom]/rp_characters/'
for name in ['config', 'wardrobe', 'appearance']:
    lua.execute(Path(root + 'shared/' + name + '.lua').read_text(encoding='utf-8'))
a = lua.globals().Characters.Appearance

def convert(table):
    return {key: convert(value) if hasattr(value, 'items') else value for key, value in table.items()}

result = []
for sex in [0, 1]:
    fields = []
    for _, field in a.fields.items():
        if not a.visible(field, sex):
            continue
        item = {key: field[key] for key in ['key', 'label', 'group', 'section', 'min', 'max']}
        item['color'] = bool(field.color)
        if field.drawable:
            item['max'] = 11 if field.group != 'hair' else 0
        elif field.key == 'hair_1':
            item['max'] = 78 if sex == 0 else 82
        options = a.options(field, sex)
        if options:
            item['options'] = [{'value': o.value, 'label': o.label} for _, o in options.items()]
        fields.append(item)
    result.append({'skin': convert(a.defaults(sex)), 'fields': fields,
                   'tops': convert(lua.globals().Characters.Wardrobe[sex].torso_1)})
path = Path('server-data/resources/[custom]/rp_ui/web/src/lib/appearance-preview.json')
path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(f'Exported {len(result)} freemode catalogs to {path}')
