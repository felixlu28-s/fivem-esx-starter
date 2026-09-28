"""Prove new male/female products build from local stock with networking disabled."""
import hashlib
import importlib.util
import json
import pathlib
import sys
import tempfile
from unittest.mock import patch

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
spec = importlib.util.spec_from_file_location('artwork_importer', ROOT / 'tools/import-item-artwork.py')
importer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(importer)
library = importer.LIBRARY
manifest = library.load_manifest()
assert manifest, 'Run --prefetch-all-clothing first'
active = json.loads((importer.OUT / 'sources.json').read_text(encoding='utf-8'))['assets']
probes = []
for sex, gender in enumerate(('male', 'female')):
    candidates = [path for path, entry in manifest['assets'].items()
                  if path.startswith(f'renders/{gender}/jbib/') and path.endswith('_0.webp') and entry['bounds']]
    path = max(candidates, key=lambda p: int(pathlib.PurePosixPath(p).stem.split('_')[0]))
    drawable = int(pathlib.PurePosixPath(path).stem.split('_')[0])
    key = f'clothing/{sex}/top/{drawable}_0'
    assert key not in active, 'Choose a genuinely unused future product'
    source = library.url_prefix + path
    assert not (importer.CACHE / hashlib.sha256(source.encode()).hexdigest()).exists(), 'Probe must not be in HTTP cache'
    probes.append((sex, drawable, key, path))

with tempfile.TemporaryDirectory(prefix='rp-clothing-library-') as directory:
    temporary = pathlib.Path(directory)
    custom = temporary / 'server-data/resources/[custom]'
    shared = custom / 'rp_inventory/shared'
    shared.mkdir(parents=True)
    catalog = (importer.CUSTOM / 'rp_inventory/shared/clothing_catalog.lua').read_text(encoding='utf-8')
    for sex, drawable, _, _ in probes:
        catalog += f"\nproduct({sex}, 'top', {drawable}, 'Library probe', 1, 0, 15)\n"
    (shared / 'clothing_catalog.lua').write_text(catalog, encoding='utf-8')
    wardrobe = custom / 'rp_characters/shared/wardrobe.lua'
    wardrobe.parent.mkdir(parents=True)
    wardrobe.write_bytes((importer.CUSTOM / 'rp_characters/shared/wardrobe.lua').read_bytes())
    translations = temporary / 'tools/catalog/clothing-de.json'
    translations.parent.mkdir(parents=True)
    translations.write_bytes((ROOT / 'tools/catalog/clothing-de.json').read_bytes())
    (custom / 'rp_ui/web/src/data').mkdir(parents=True)
    importer.ROOT, importer.CUSTOM = temporary, custom
    importer.OUT = custom / 'rp_ui/web/public/catalog'
    importer.OFFLINE = True
    with patch('urllib.request.urlopen', side_effect=AssertionError('Offline import tried to use the network')):
        importer.main()
    exported = json.loads((importer.OUT / 'sources.json').read_text(encoding='utf-8'))['assets']
    for _, _, key, path in probes:
        data = (importer.OUT / (key + '.webp')).read_bytes()
        assert data == (library.root / path).read_bytes()
        assert exported[key]['sha256'] == manifest['assets'][path]['sha256']
    assert len(exported) < 1500, 'Unused library artwork must not enter the game packfile'

    # Detect a damaged stocked image rather than silently publishing it.
    from catalog.clothing_library import ClothingLibrary
    damaged = ClothingLibrary(temporary, library.revision)
    path = probes[0][3]
    target = damaged.root / path
    target.parent.mkdir(parents=True)
    target.write_bytes(b'broken')
    damaged.manifest = manifest
    try:
        damaged.read(damaged.url_prefix + path)
    except ValueError as error:
        assert 'damaged' in str(error)
    else:
        raise AssertionError('Damaged artwork was accepted')

print('PASS: previously unused male/female clothing imports offline from verified stock; '
      'game package stays small; damaged images are rejected')
