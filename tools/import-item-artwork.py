"""Import original GTA artwork; no runtime CDN dependency and no image re-encoding.

Run in a Python environment with lupa and Pillow. See docs/item-catalog.md.
"""
import argparse
import concurrent.futures
import hashlib
import io
import json
import pathlib
import re
import urllib.error
import urllib.request

from catalog.clothing_library import ClothingLibrary, atomic_write

from lupa.lua54 import LuaRuntime
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[1]
CUSTOM = ROOT / 'server-data/resources/[custom]'
OUT = CUSTOM / 'rp_ui/web/public/catalog'
CACHE = ROOT / '.codex-log/catalog-sources'
CACHE.mkdir(parents=True, exist_ok=True)
REVISIONS = {
    'Reizenkun/gtav-fivem-clothes': 'c04b147a8aa7f5164ef4b029dc091e98b35ca02f',
    'root-cause/v-clothingnames': '84020cfa80b1a2fdc86f0e8eb438d313f343c015',
    'DurtyFree/gta-v-data-dumps': 'b65684e00f689fdec405c5f1055322c802d3c895',
    'overextended/ox_inventory': '172b3914d0cf1967ead8cccc583763e8d5316eb7',
    'Colbss/FiveM-ClothingData': '6178655616ea88e3e2bf191b32bc4878b9c3b5eb',
}
LIBRARY = ClothingLibrary(ROOT, REVISIONS['Reizenkun/gtav-fivem-clothes'])
OFFLINE = False


def download(url):
    local = LIBRARY.read(url)
    if local is not None:
        return local
    cache = CACHE / hashlib.sha256(url.encode()).hexdigest()
    if cache.exists():
        return cache.read_bytes()
    if OFFLINE:
        raise FileNotFoundError(f'Not available locally (offline import): {url}')
    with urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'rp-item-catalog/1.0'}), timeout=40) as response:
        data = response.read()
    atomic_write(cache, data)
    return data


def raw(repo, path):
    return f'https://raw.githubusercontent.com/{repo}/{REVISIONS[repo]}/{path}'


def lua(value):
    if value is None:
        return 'nil'
    if isinstance(value, bool):
        return str(value).lower()
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, list):
        return '{' + ','.join(map(lua, value)) + '}'
    return '{' + ','.join('[' + lua(k) + ']=' + lua(v) for k, v in value.items()) + '}'


PARTS = {'top': ('jbib', 'tops'), 'undershirt': ('accs', 'undershirts'), 'pants': ('lowr', 'legs'),
         'shoes': ('feet', 'shoes'), 'chain': ('teef', 'accessories'), 'bag': ('hand', None),
         'mask': ('berd', 'masks'), 'hat': ('p_head', 'hats'), 'glasses': ('p_eyes', 'glasses'),
         'ears': ('p_ears', 'ears'), 'watch': ('p_lwrist', 'watches'), 'bracelet': ('p_rwrist', 'bracelets')}


def main():
    LIBRARY.load_manifest()
    runtime = LuaRuntime(unpack_returned_tuples=True)
    runtime.execute((CUSTOM / 'rp_inventory/shared/clothing_catalog.lua').read_text(encoding='utf-8'))
    runtime.execute('Characters = {}')
    runtime.execute((CUSTOM / 'rp_characters/shared/wardrobe.lua').read_text(encoding='utf-8'))
    clothing = runtime.globals().Clothing
    selected = {(sex, cat): set() for sex in (0, 1) for cat in PARTS}
    for product in clothing.products.values():
        prefix = clothing.categories[product.category].prefix
        selected[product.sex, product.category].add(product.skin[prefix + '_1'])
    for sex in (0, 1):
        for cat in PARTS:
            choices = runtime.globals().Characters.Wardrobe[sex][clothing.categories[cat].prefix + '_1']
            if choices:
                selected[sex, cat].update(r.value for r in choices.values() if r.value >= 0)
    index = json.loads(download(raw('Reizenkun/gtav-fivem-clothes', 'renders/index.json')))
    names = {}
    for sex, gender in enumerate(('male', 'female')):
        for cat, (part, suffix) in PARTS.items():
            if not suffix:
                continue
            file = f'props_{gender}_{suffix}' if part.startswith('p_') else f'masks_{gender}' if cat == 'mask' else f'{gender}_{suffix}'
            names[sex, cat] = json.loads(download(raw('root-cause/v-clothingnames', file + '.json')))
    assets, garments, jobs = {}, {}, []
    translations = json.loads((ROOT / 'tools/catalog/clothing-de.json').read_text(encoding='utf-8'))
    for (sex, cat), drawables in selected.items():
        gender = ('male', 'female')[sex]
        part = PARTS[cat][0]
        for row in index[gender][part]:
            d, t = row['drawable'], row['texture']
            if d not in drawables:
                continue
            key = f'clothing/{sex}/{cat}/{d}_{t}'
            source = names.get((sex, cat), {}).get(str(d), {}).get(str(t), {})
            gxt = source.get('GXT', '')
            if not gxt or gxt in ('NO_LABEL', 'NULL') or source.get('Localized') in ('None', 'NULL', 'NO_LABEL'):
                gxt = None
            garments[key] = {'label': translations.get(source.get('Localized'), f'{clothing.categories[cat].label} {d:02d} · {t + 1:02d}'),
                             'gxt': gxt, 'english': source.get('Localized'), 'artwork': key}
            jobs.append((key, raw('Reizenkun/gtav-fivem-clothes', row['path']), 'webp'))
    # Complement holes in the first render set using the second author's base
    # collection. These IDs are base-game global == collection-local IDs.
    component = {'top':11,'undershirt':8,'pants':4,'shoes':6,'chain':7,'bag':5,'mask':1,'hat':0,'glasses':1,'ears':2,'watch':6,'bracelet':7}
    for product in clothing.products.values():
        sex, cat = product.sex, product.category
        d = product.skin[clothing.categories[cat].prefix + '_1']
        key = f'clothing/{sex}/{cat}/{d}_0'
        if key in garments:
            continue
        gender, model = ('male','female')[sex], ('mp_m_freemode_01','mp_f_freemode_01')[sex]
        source = names.get((sex, cat), {}).get(str(d), {}).get('0', {})
        gxt = source.get('GXT')
        if gxt in ('NO_LABEL','NULL') or source.get('Localized') in ('None','NULL','NO_LABEL'): gxt = None
        garments[key] = {'label': translations.get(source.get('Localized'), f'{clothing.categories[cat].label} {d:02d} · 01'),
                         'english': source.get('Localized'), 'gxt': gxt, 'artwork': key}
        prefix = 'P' if PARTS[cat][0].startswith('p_') else 'D'
        jobs.append((key, raw('Colbss/FiveM-ClothingData', f'images/{model}/base/{prefix}_{component[cat]}_{d}_0.webp'), 'webp'))
    data = json.loads(download(raw('DurtyFree/gta-v-data-dumps', 'weapons.json')))
    docs = download('https://docs.fivem.net/docs/game-references/weapon-models/').decode()
    supported = set(re.findall(r'weapons/(WEAPON_[A-Z0-9_]+)\.png', docs)) - {'WEAPON_UNARMED'}
    weapons = {}
    for row in data:
        name = row['Name']
        if name not in supported:
            continue
        label = row['TranslatedLabel'].get('German')
        # Invalid/debug game labels need an explicit, reviewable fallback.
        if not label or label == 'Ungültig':
            label = {'WEAPON_GRENADELAUNCHER_SMOKE': 'Rauchgranatenwerfer', 'WEAPON_FIREEXTINGUISHER': 'Feuerlöscher'}.get(name)
        assert label, f'Missing German weapon label: {name}'
        weapons[name] = {'label': label, 'category': row['Category'], 'nativeAmmo': row['AmmoType'],
                         'model': row['ModelName'], 'dlc': row['DlcName'], 'artwork': f'weapons/{name}'}
        jobs.append((f'weapons/{name}', raw('overextended/ox_inventory', f'web/images/{name}.png'), 'png'))

    def asset(job):
        key, url, extension = job
        try:
            data = download(url)
        except (urllib.error.HTTPError, FileNotFoundError) as error:
            if not key.startswith('weapons/') or (isinstance(error, urllib.error.HTTPError) and error.code != 404):
                raise
            url = f'https://docs-backend.fivem.net/{key}.png'
            data = download(url)
        image = Image.open(io.BytesIO(data))
        bounds = image.convert('RGBA').getchannel('A').getbbox()
        if not bounds:
            return key, None  # Invisible model: don't present a fabricated garment.
        path = OUT / (key + '.' + extension)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        x, y, right, bottom = bounds
        return key, {'src': f'catalog/{key}.{extension}', 'width': image.width, 'height': image.height,
                     'bounds': [x, y, right - x, bottom - y], 'source': url, 'sha256': hashlib.sha256(data).hexdigest()}

    print(f'Importing {len(jobs)} images...', flush=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        for i, (key, value) in enumerate(pool.map(asset, jobs)):
            if value:
                assets[key] = value
            else:
                garments[key]['artwork'] = None
            if (i + 1) % 250 == 0:
                print(f'{i + 1}/{len(jobs)}', flush=True)
    generated = CUSTOM / 'rp_inventory/shared'
    generated.joinpath('clothing_artwork.lua').write_text('-- Generated by tools/import-item-artwork.py\nClothingArtwork = ' + lua(garments) + '\n', encoding='utf-8')
    generated.joinpath('weapon_catalog.lua').write_text('-- Generated by tools/import-item-artwork.py\nWeaponCatalog = ' + lua(weapons) + '\n', encoding='utf-8')
    browser = CUSTOM / 'rp_ui/web/src/data'
    browser.mkdir(exist_ok=True)
    browser.joinpath('item-artwork.json').write_text(json.dumps({k: {f: v[f] for f in ('src','width','height','bounds')} for k,v in assets.items()}, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    # Studio uses the same products/prices/images as the real shop.
    runtime.execute(generated.joinpath('clothing_artwork.lua').read_text(encoding='utf-8'))
    runtime.execute(generated.joinpath('clothing_catalog.lua').read_text(encoding='utf-8'))
    clothing = runtime.globals().Clothing
    preview = []
    for p in sorted(clothing.products.values(), key=lambda p: p.id):
        if p.sex != 0 or p.hidden: continue
        cat = clothing.categories[p.category]
        preview.append({'id': p.id, 'label': p.label, 'artwork': p.artwork, 'icon': 'clothes',
                        'description': p.label, 'category': cat.label, 'weight': cat.weight, 'price': p.price,
                        'count': 1, 'seconds': 0, 'owned': 0, 'ingredients': [],
                        'garment': {'category': p.category, 'image': p.image, 'color': p.color, 'view': cat.view}})
    browser.joinpath('clothing-preview.json').write_text(json.dumps(preview, ensure_ascii=False, indent=2), encoding='utf-8')
    OUT.joinpath('sources.json').write_text(json.dumps({'revisions': REVISIONS, 'assets': assets}, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f'{len(assets)} pictures, {len(weapons)} weapons, {len(garments)} garment variants', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--prefetch-all-clothing', action='store_true', help='Download/verify all upstream renders outside the game packfile')
    mode.add_argument('--verify-clothing-library', action='store_true', help='Verify every prefetched file against the pinned index and checksums')
    parser.add_argument('--offline', action='store_true', help='Forbid network access; build from local stock/cache only')
    args = parser.parse_args()
    OFFLINE = args.offline
    if args.prefetch_all_clothing:
        if OFFLINE:
            parser.error('--offline cannot be combined with --prefetch-all-clothing; use --verify-clothing-library')
        LIBRARY.prefetch(download(raw('Reizenkun/gtav-fivem-clothes', 'renders/index.json')))
    elif args.verify_clothing_library:
        LIBRARY.verify()
    else:
        main()
