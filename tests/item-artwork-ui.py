"""Exact local asset integrity, both sex catalogues, responsive UI and drag artwork."""
import hashlib
import json
from pathlib import Path
from lupa.lua54 import LuaRuntime
from PIL import Image
from playwright.sync_api import sync_playwright, expect

custom = Path('server-data/resources/[custom]')
public = custom / 'rp_ui/web/public'
manifest = json.loads((public / 'catalog/sources.json').read_text(encoding='utf-8'))
for key, asset in manifest['assets'].items():
    path = public / asset['src']
    assert hashlib.sha256(path.read_bytes()).hexdigest() == asset['sha256'], key
    image = Image.open(path).convert('RGBA')
    assert image.getchannel('A').getextrema()[0] == 0, key
    assert min(asset['bounds'][2:]) > 0, key
assert len(manifest['assets']) == 1403
assert sum(key.startswith('weapons/') for key in manifest['assets']) == 110

lua = LuaRuntime(unpack_returned_tuples=True)
for file in ['clothing_artwork', 'clothing_catalog']:
    lua.execute((custom / f'rp_inventory/shared/{file}.lua').read_text(encoding='utf-8'))
C = lua.globals().Clothing
female = []
for p in sorted(C.products.values(), key=lambda p: p.id):
    if p.sex != 1 or p.hidden: continue
    category = C.categories[p.category]
    female.append(dict(id=p.id, label=p.label, artwork=p.artwork, icon='clothes', description=p.label,
                       category=category.label, weight=category.weight, price=p.price, count=1, seconds=0, owned=0,
                       ingredients=[], garment=dict(category=p.category, image=p.image, color=p.color, view=category.view)))

with sync_playwright() as p:
    browser = p.chromium.launch(channel='chrome', headless=True)
    page = browser.new_page(viewport={'width':1920,'height':1080})
    errors, missing = [], []
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.on('response', lambda r: missing.append(r.url) if '/catalog/' in r.url and r.status != 200 else None)
    page.goto('http://127.0.0.1:5173/?view=clothing', wait_until='networkidle')
    fixture = page.evaluate("async()=> (await import('/src/lib/clothingPreview.ts')).clothingPreview()")
    for width, height in [(1280,720),(1920,1080),(3840,2160),(3440,1440)]:
        page.set_viewport_size({'width':width,'height':height})
        for offers in [fixture['offers'], female]:
            payload = dict(fixture, offers=offers, currentClothing=[])
            page.evaluate("()=>window.postMessage({action:'ui:close'},'*')")
            expect(page.locator('.clothing-screen')).to_have_count(0)
            page.evaluate("payload=>window.postMessage({action:'ui:open',data:{view:'clothing',locked:false,payload}},'*')", payload)
            for category in dict.fromkeys(o['category'] for o in offers):
                page.get_by_role('navigation', name='Kategorien').get_by_role('button', name=category, exact=True).click()
                count = sum(o['category'] == category for o in offers)
                expect(page.locator('.clothing-product .catalog-image image')).to_have_count(count)
                bounds = page.locator('.clothing-panel').bounding_box()
                assert 0 <= bounds['x'] and bounds['x']+bounds['width'] <= width+1
                assert bounds['y']+bounds['height'] <= height+1
        page.screenshot(path=f'.codex-log/item-artwork-{width}.png')
    page.set_viewport_size({'width':1920,'height':1080})
    page.goto('http://127.0.0.1:5173/?view=inventory', wait_until='networkidle')
    slot = lambda n: page.locator(f'.inventory-slot[data-side="own"][data-slot="{n}"]')
    for origin, target in [(7,5),(17,6)]:
        source_image = slot(origin).locator('.catalog-image image').get_attribute('href')
        a,b = slot(origin).bounding_box(),slot(target).bounding_box()
        page.mouse.move(a['x']+30,a['y']+40); page.mouse.down()
        page.mouse.move(b['x']+30,b['y']+40,steps=12)
        expect(page.locator('.inventory-drag-ghost .catalog-image image')).to_have_attribute('href',source_image)
        page.mouse.up()
        expect(slot(target).locator('.catalog-image image')).to_have_attribute('href',source_image)
    # Data-supplied external URLs cannot become image URLs in the typed NUI path.
    assert page.evaluate("async()=> { const {parseInventory}=await import('/src/lib/inventory.ts'); const p=(await import('/src/lib/inventoryPreview.ts')).inventoryPreview(); p.own.items[0].artwork='https://example.org/track.png'; return parseInventory(p)===null; }")
    assert not errors, errors
    assert not missing, missing
    browser.close()
print('PASS: 1403 unchanged transparent assets; 167 garments, both sexes and four resolutions; exact drag images; safe local URLs')
