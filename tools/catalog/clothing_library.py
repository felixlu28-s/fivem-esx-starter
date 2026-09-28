"""Local, revision-pinned artwork stock, deliberately outside the FiveM packfile."""
import hashlib
import io
import json
import pathlib
import re
import tarfile
import time
import urllib.error
import urllib.request

from PIL import Image

REPOSITORY = 'Reizenkun/gtav-fivem-clothes'
PARTS = {'accs', 'berd', 'decl', 'feet', 'hair', 'hand', 'head', 'jbib',
         'lowr', 'p_ears', 'p_eyes', 'p_head', 'p_lwrist', 'p_rwrist', 'task', 'teef', 'uppr'}


def atomic_write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + '.part')
    temporary.write_bytes(data)
    temporary.replace(path)


def image_info(data):
    with Image.open(io.BytesIO(data)) as image:
        if image.format != 'WEBP':
            raise ValueError('Expected original WebP artwork')
        bounds = image.convert('RGBA').getchannel('A').getbbox()
        if bounds:
            x, y, right, bottom = bounds
            bounds = [x, y, right - x, bottom - y]
        return {'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data),
                'width': image.width, 'height': image.height, 'bounds': bounds}


class ClothingLibrary:
    def __init__(self, root, revision):
        if not re.fullmatch(r'[0-9a-f]{40}', revision):
            raise ValueError('Expected pinned Git revision')
        self.revision = revision
        self.root = root / 'assets/clothing-library/reizenkun' / revision
        self.cache = root / '.codex-log/catalog-sources'
        self.url_prefix = f'https://raw.githubusercontent.com/{REPOSITORY}/{revision}/'
        self.manifest = None

    @staticmethod
    def paths(index):
        expected = {}
        if set(index) != {'male', 'female'}:
            raise ValueError('Unexpected clothing model in index')
        for gender, parts in index.items():
            for part, rows in parts.items():
                if part not in PARTS:
                    raise ValueError(f'Unexpected clothing part: {part}')
                for row in rows:
                    drawable, texture = row['drawable'], row['texture']
                    if type(drawable) is not int or type(texture) is not int or min(drawable, texture) < 0:
                        raise ValueError('Invalid drawable/texture in index')
                    path = f'renders/{gender}/{part}/{drawable}_{texture}.webp'
                    if row['path'] != path or path in expected:
                        raise ValueError(f'Invalid or duplicate render path: {row["path"]}')
                    expected[path] = {'gender': gender, 'part': part, 'drawable': drawable, 'texture': texture}
        if not expected:
            raise ValueError('Empty render index')
        return expected

    def load_manifest(self):
        if self.manifest is None:
            path = self.root / 'manifest.json'
            if not path.is_file():
                return None
            manifest = json.loads(path.read_text(encoding='utf-8'))
            if manifest['repository'] != REPOSITORY or manifest['revision'] != self.revision:
                raise ValueError('Clothing library revision mismatch')
            self.manifest = manifest
        return self.manifest

    def read(self, url):
        """Prefer verified local stock over the download cache or network."""
        if not url.startswith(self.url_prefix):
            return None
        path = url[len(self.url_prefix):]
        if not re.fullmatch(r'renders/(male|female)/[a-z_]+/\d+_\d+\.webp', path):
            return None
        manifest = self.load_manifest()
        entry = manifest and manifest['assets'].get(path)
        if not entry:
            return None
        data = (self.root / path).read_bytes()
        if hashlib.sha256(data).hexdigest() != entry['sha256']:
            raise ValueError(f'Local clothing artwork is damaged: {path}; run --prefetch-all-clothing to repair')
        return data

    def archive(self):
        self.cache.mkdir(parents=True, exist_ok=True)
        path = self.cache / f'clothing-{self.revision}.tar.gz'
        if path.is_file():
            return path
        url = f'https://codeload.github.com/{REPOSITORY}/tar.gz/{self.revision}'
        request = urllib.request.Request(url, headers={'User-Agent': 'rp-item-catalog/1.0'})
        partial = path.with_suffix(path.suffix + '.part')
        for attempt in range(3):
            try:
                with urllib.request.urlopen(request, timeout=60) as response, partial.open('wb') as target:
                    size, last = 0, time.monotonic()
                    while block := response.read(1024 * 1024):
                        target.write(block)
                        size += len(block)
                        if time.monotonic() - last >= 10:
                            print(f'Clothing archive: {size / 1024**2:.0f} MiB downloaded', flush=True)
                            last = time.monotonic()
                partial.replace(path)
                print(f'Clothing archive ready: {size / 1024**2:.1f} MiB', flush=True)
                return path
            except (urllib.error.URLError, TimeoutError, ConnectionError) as error:
                if attempt == 2:
                    raise
                print(f'Archive download interrupted ({error}); retry {attempt + 1}/2', flush=True)
                time.sleep(2 ** attempt)

    def prefetch(self, index_bytes):
        index = json.loads(index_bytes)
        expected = self.paths(index)
        prior = self.load_manifest()
        if prior and prior.get('indexSha256') == hashlib.sha256(index_bytes).hexdigest():
            try:
                return self.verify()
            except (OSError, ValueError) as error:
                print(f'Repairing local library: {error}', flush=True)
        archive = self.archive()
        assets = {}
        prefix = f'gtav-fivem-clothes-{self.revision}/'
        # Never extractall: archive names and links cannot choose output paths.
        with tarfile.open(archive, mode='r|gz') as source:
            for member in source:
                if not member.name.startswith(prefix):
                    continue
                path = member.name[len(prefix):]
                if path not in expected:
                    continue
                if not member.isfile() or member.size > 20 * 1024 * 1024 or path in assets:
                    raise ValueError(f'Invalid archive entry: {path}')
                with source.extractfile(member) as stream:
                    data = stream.read()
                info = image_info(data)
                target = self.root / path
                if not target.is_file() or target.read_bytes() != data:
                    atomic_write(target, data)
                assets[path] = info
                if len(assets) % 1000 == 0:
                    print(f'Validated and stored {len(assets)}/{len(expected)} renders', flush=True)
        missing = expected.keys() - assets.keys()
        if missing:
            raise ValueError(f'Incomplete upstream archive: {len(missing)} missing renders, e.g. {sorted(missing)[:3]}')
        manifest = {'repository': REPOSITORY, 'revision': self.revision,
                    'source': f'https://github.com/{REPOSITORY}/tree/{self.revision}',
                    'indexSha256': hashlib.sha256(index_bytes).hexdigest(),
                    'total': len(assets), 'bytes': sum(a['bytes'] for a in assets.values()),
                    'empty': sum(a['bounds'] is None for a in assets.values()),
                    'assets': dict(sorted(assets.items()))}
        atomic_write(self.root / 'index.json', index_bytes)
        atomic_write(self.root / 'manifest.json', json.dumps(manifest, ensure_ascii=False, indent=2).encode('utf-8'))
        self.manifest = manifest
        self.report(manifest)
        return manifest

    def verify(self):
        manifest = self.load_manifest()
        if not manifest:
            raise ValueError('Clothing library not downloaded; run --prefetch-all-clothing first')
        index_bytes = (self.root / 'index.json').read_bytes()
        expected = self.paths(json.loads(index_bytes))
        if hashlib.sha256(index_bytes).hexdigest() != manifest['indexSha256'] or expected.keys() != manifest['assets'].keys():
            raise ValueError('Library index/manifest is incomplete or changed')
        for number, (path, entry) in enumerate(manifest['assets'].items(), 1):
            data = (self.root / path).read_bytes()
            if len(data) != entry['bytes'] or hashlib.sha256(data).hexdigest() != entry['sha256']:
                raise ValueError(f'Clothing checksum failed: {path}')
            if number % 5000 == 0:
                print(f'Checked {number}/{len(expected)} local files', flush=True)
        if manifest['total'] != len(expected) or manifest['bytes'] != sum(a['bytes'] for a in manifest['assets'].values()):
            raise ValueError('Library totals do not match manifest')
        self.report(manifest)
        return manifest

    @staticmethod
    def report(manifest):
        print(f'Local clothing library complete: {manifest["total"]} original renders, '
              f'{manifest["bytes"] / 1024**2:.1f} MiB, '
              f'{manifest["empty"]} transparent/empty source renders. No runtime packfile expansion.', flush=True)
