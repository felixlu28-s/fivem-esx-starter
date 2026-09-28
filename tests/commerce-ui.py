"""Real shop/crafting React flows, responsive layout and validated NUI replies."""
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

out = Path('.codex-log')
out.mkdir(exist_ok=True)
errors = []
with sync_playwright() as p:
    browser = p.chromium.launch(channel='chrome', headless=True)
    page = browser.new_page(viewport={'width':1920,'height':1080})
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.goto('http://127.0.0.1:5173/?view=shop')
    expect(page.locator('.commerce-product')).to_have_count(7)
    page.get_by_label('Menge', exact=True).fill('2')
    expect(page.locator('.commerce-total')).to_contain_text('$24')
    page.get_by_role('button', name='Kaufen', exact=True).click()
    expect(page.get_by_role('status')).to_contain_text('Einkauf')
    expect(page.locator('.commerce-meta')).to_contain_text('6 in deinen Taschen')
    expect(page.get_by_role('button', name='Bargeld', exact=False)).to_contain_text('$1.226')
    page.get_by_role('button', name='Karte', exact=False).click()
    page.get_by_role('button', name='Kaufen', exact=True).click()
    expect(page.get_by_role('button', name='Karte', exact=False)).to_contain_text('$8.726')
    page.get_by_role('button', name='Material', exact=True).click()
    expect(page.locator('.commerce-product')).to_have_count(3)
    page.get_by_label('Artikel suchen').fill('Garn')
    expect(page.locator('.commerce-product')).to_have_count(1)
    page.locator('.commerce-product').click()
    expect(page.locator('.commerce-detail h2')).to_have_text('Nähgarn')
    page.get_by_label('Menge', exact=True).fill('999')
    expect(page.get_by_label('Menge', exact=True)).to_have_value('20')

    page.goto('http://127.0.0.1:5173/?view=crafting')
    page.get_by_role('button', name='Herstellen', exact=True).click()
    expect(page.get_by_role('progressbar')).to_be_visible()
    page.get_by_role('button', name='Abbrechen', exact=True).click()
    expect(page.locator('.commerce-ingredients')).to_contain_text('12 / 2')
    page.get_by_role('button', name='Herstellen', exact=True).click()
    expect(page.get_by_role('status')).to_contain_text('Fertig', timeout=8000)
    expect(page.locator('.commerce-ingredients')).to_contain_text('10 / 2')
    expect(page.locator('.commerce-meta')).to_contain_text('1 in deinen Taschen')
    page.locator('.commerce-product').filter(has_text='Reiserucksack').click()
    expect(page.get_by_role('button', name='Herstellen', exact=True)).to_be_disabled()
    expect(page.locator('.commerce-hint')).to_contain_text('fehlen Materialien')

    for width,height in [(1280,720),(1366,768),(1920,1080),(2560,1440),(3840,2160),(3440,1440),(740,900)]:
        page.set_viewport_size({'width':width,'height':height})
        for view in ['shop','crafting']:
            page.goto(f'http://127.0.0.1:5173/?view={view}')
            expect(page.locator('.commerce-shell')).to_be_visible()
            boxes = [page.locator(selector).bounding_box() for selector in ['.commerce-catalog','.commerce-detail']]
            assert all(b and b['x'] >= 0 and b['y'] >= 0 and b['x']+b['width'] <= width+1 and b['y']+b['height'] <= height+1 for b in boxes), (view,width,boxes)
            assert boxes[0]['x']+boxes[0]['width'] <= boxes[1]['x'], (view,width,boxes)
            if width in (1920,3840): page.screenshot(path=str(out / f'commerce-{view}-{width}.png'))

    # True NUI path with payload validation and loss-safe in-flight handling.
    context = browser.new_context(viewport={'width':1920,'height':1080})
    context.add_init_script("window.GetParentResourceName = () => 'rp_ui'")
    context.route('https://rp_ui/**', lambda route: route.fulfill(json={'ok':True}))
    game = context.new_page()
    game.on('pageerror', lambda error: errors.append(str(error)))
    game.goto('http://127.0.0.1:5173/?view=shop')
    fixture = game.evaluate("async () => (await import('/src/lib/commercePreview.ts')).commercePreview('shop')")
    fixture.pop('job', None)  # Browser RPC serializes JS undefined as Python None; Lua omits this field.
    def show(value):
        game.evaluate("p => window.postMessage({action:'ui:open',data:{view:'commerce',locked:false,payload:p}},location.origin)",value)
    show(fixture)
    pending = []
    game.route('https://rp_ui/rp_commerce:action', lambda route: pending.append(route))
    game.get_by_role('button', name='Kaufen', exact=True).click()
    expect(game.get_by_role('button', name='Wird verarbeitet …')).to_be_disabled()
    assert len(pending) == 1
    packet = pending[0].request.post_data_json
    assert packet['offer'] == 'water' and packet['quantity'] == 1 and 'price' not in packet and 'total' not in packet
    invalid = dict(fixture, cash=-99)
    pending.pop().fulfill(json={'ok':True,'commerce':invalid})
    expect(game.get_by_role('status')).to_contain_text('Antwort fehlt')
    expect(game.get_by_role('button', name='Bargeld', exact=False)).to_contain_text('$1.250')
    game.get_by_role('button', name='Kaufen', exact=True).click()
    assert pending[0].request.post_data_json['request'] == packet['request'], 'retry keeps idempotency key'
    game.keyboard.press('Escape')
    expect(game.locator('.commerce-shell')).to_have_count(0)
    pending.pop().fulfill(json={'ok':True,'commerce':fixture})
    game.wait_for_timeout(100)
    expect(game.locator('.commerce-shell')).to_have_count(0)
    browser.close()
assert not errors, errors
print('PASS: shop cash/card, quantities, categories/search, timed crafting/cancellation/materials, 14 layouts through 4K, NUI validation, duplicate-click prevention, retry key, late reply cleanup')
