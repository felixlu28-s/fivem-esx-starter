"""Actual React inventory: browser interactions and HD/4K layout, plus NUI validation."""
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

out = Path('.codex-log')
out.mkdir(exist_ok=True)
errors = []
url = 'http://127.0.0.1:5173/?view=inventory'
with sync_playwright() as p:
    browser = p.chromium.launch(channel='chrome', headless=True)
    page = browser.new_page(viewport={'width': 1920, 'height': 1080})
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.goto(url, wait_until='networkidle')
    slot = lambda side, n: page.locator(f'.inventory-slot[data-side="{side}"][data-slot="{n}"]')
    expect(page.locator('.inventory-slot')).to_have_count(40)
    expect(page.get_by_role('button', name='Inventar aktualisieren')).to_have_count(0)
    # Real pointer movement + Escape cancels without moving/dropping or closing the UI.
    origin = slot('own', 1).bounding_box()
    tile_background = slot('own', 1).evaluate('(e) => getComputedStyle(e).backgroundImage')
    destination = slot('own', 5).bounding_box()
    page.mouse.move(origin['x'] + 30, origin['y'] + 40)
    page.mouse.down()
    page.mouse.move(destination['x'] + 30, destination['y'] + 40, steps=4)
    expect(page.locator('.inventory-drag-ghost')).to_be_visible()
    ghost = page.locator('.inventory-drag-ghost')
    ghost_box = ghost.bounding_box()
    assert abs(ghost_box['width'] - origin['width']) < 1 and abs(ghost_box['height'] - origin['height']) < 1
    assert abs(ghost_box['x'] - destination['x']) < 1 and abs(ghost_box['y'] - destination['y']) < 1
    assert ghost.evaluate('(e) => getComputedStyle(e).backgroundImage') == tile_background
    expect(ghost.locator('.inventory-slot-count')).to_contain_text('4')
    expect(ghost.locator('.inventory-item-label')).to_have_text('Mineralwasser')
    assert slot('own', 1).locator('svg').evaluate('(e) => getComputedStyle(e).visibility') == 'hidden'
    page.keyboard.press('Escape')
    page.mouse.up()
    expect(page.locator('.inventory-drag-ghost')).to_have_count(0)
    expect(page.locator('.inventory-shell')).to_be_visible()
    expect(slot('own', 1)).to_have_attribute('aria-label', 'Deine Taschen, Platz 1: Mineralwasser, 4 Stück')
    # Quantity survives drag start and splits, rather than copying, the original stack.
    expect(page.locator('.inventory-shell > .inventory-store')).to_have_count(2)
    expect(page.locator('.inventory-header, .inventory-footer, .inventory-equipment, .inventory-status')).to_have_count(0)
    slot('own', 1).click(button='right')
    box = slot('own', 1).bounding_box()
    menu = page.get_by_role('dialog', name='Gegenstandsaktionen')
    menu_box = menu.bounding_box()
    assert abs(menu_box['x'] - (box['x'] + box['width']/2)) < 3 and abs(menu_box['y'] - (box['y'] + box['height']/2)) < 3
    page.get_by_label('Menge', exact=True).fill('2')
    page.get_by_role('button', name='Menge fürs Ziehen übernehmen').click()
    slot('own', 1).drag_to(slot('own', 5))
    expect(slot('own', 1)).to_have_attribute('aria-label', 'Deine Taschen, Platz 1: Mineralwasser, 2 Stück')
    expect(slot('own', 5)).to_have_attribute('aria-label', 'Deine Taschen, Platz 5: Mineralwasser, 2 Stück')
    slot('own', 5).drag_to(slot('external', 1))
    expect(slot('external', 1)).to_have_attribute('aria-label', 'Testkiste, Platz 1: Mineralwasser, 3 Stück')
    expect(slot('own', 5)).to_have_attribute('aria-label', 'Deine Taschen, Platz 5, leer')
    slot('external', 1).drag_to(slot('own', 5))
    expect(slot('own', 5)).to_have_attribute('aria-label', 'Deine Taschen, Platz 5: Mineralwasser, 3 Stück')
    slot('own', 5).click(button='right')
    menu.get_by_role('button', name='Benutzen', exact=True).click()
    expect(slot('own', 5)).to_have_attribute('aria-label', 'Deine Taschen, Platz 5: Mineralwasser, 2 Stück')
    slot('own', 5).click(button='right')
    expect(page.get_by_label('Gegenstandsaktionen')).to_be_visible()
    page.get_by_label('Gegenstandsaktionen').get_by_role('button', name='Ablegen').click()
    expect(slot('own', 5)).to_have_attribute('aria-label', 'Deine Taschen, Platz 5, leer')
    # Equipped backpack increases both limits and cannot be removed with items in expanded slots.
    slot('own', 13).click(button='right')
    menu.get_by_role('button', name='Benutzen', exact=True).click()
    expect(page.locator('.inventory-slot[data-side=own]')).to_have_count(32)
    page.get_by_role('button', name='Angelegter Rucksack').click()
    expect(menu).to_contain_text('+8 Plätze · +10 kg')
    page.keyboard.press('Escape')
    expect(menu).not_to_be_visible()
    expect(page.locator('.inventory-shell')).to_be_visible()
    slot('own', 2).drag_to(slot('own', 25))
    page.get_by_role('button', name='Angelegter Rucksack').click()
    menu.get_by_role('button', name='Rucksack abnehmen').click()
    expect(page.get_by_role('status')).to_contain_text('Leere zuerst')
    expect(page.locator('.inventory-slot[data-side=own]')).to_have_count(32)
    # These rows can require different scroll positions; click-to-move also
    # preserves the selected quantity across scrolling the slot grid.
    slot('own', 25).click()
    slot('own', 2).click()
    expect(slot('own', 25)).to_have_attribute('aria-label', 'Deine Taschen, Platz 25, leer')
    page.get_by_role('button', name='Angelegter Rucksack').click()
    menu.get_by_role('button', name='Rucksack abnehmen').click()
    expect(page.locator('.inventory-slot[data-side=own]')).to_have_count(24)
    # Dropping outside the panel never adds the item to the external container. Escape/cancel alone never does.
    slot('own', 3).drag_to(page.locator('.inventory-backdrop'), target_position={'x': 10, 'y': 10})
    expect(slot('own', 3)).to_have_attribute('aria-label', 'Deine Taschen, Platz 3, leer')
    assert page.locator('.inventory-slot[data-side=external]').filter(has_text='Verband').count() == 0
    # Giving consumes precisely the selected quantity; choosing a recipient is required.
    page.goto(url, wait_until='networkidle')
    slot('own', 1).click(button='right')
    page.get_by_label('Menge', exact=True).fill('2')
    menu.get_by_role('button', name='Geben', exact=True).click()
    expect(slot('own', 1)).to_have_attribute('aria-label', 'Deine Taschen, Platz 1: Mineralwasser, 4 Stück')
    menu.get_by_role('button', name='Jamie Parker', exact=False).click()
    expect(slot('own', 1)).to_have_attribute('aria-label', 'Deine Taschen, Platz 1: Mineralwasser, 2 Stück')
    expect(page.get_by_role('status')).to_contain_text('übergeben')
    slot('external', 1).click(button='right')
    expect(menu.get_by_role('button', name='Geben', exact=True)).to_have_count(0)
    menu.get_by_role('button', name='Aufnehmen', exact=True).click()
    expect(slot('own', 1)).to_have_attribute('aria-label', 'Deine Taschen, Platz 1: Mineralwasser, 3 Stück')
    # Keyboard opens the same actions and Escape first closes just this menu.
    slot('own', 1).focus()
    page.keyboard.press('Shift+F10')
    expect(menu).to_be_visible()
    page.keyboard.press('Escape')
    expect(menu).not_to_be_visible()
    expect(page.locator('.inventory-shell')).to_be_visible()
    measurements = {}
    for width, height in [(1280,720),(1366,768),(1920,1080),(2560,1440),(3840,2160),(3440,1440),(740,900)]:
        page.set_viewport_size({'width':width,'height':height})
        page.goto(url, wait_until='networkidle')
        box = page.locator('.inventory-shell').bounding_box()
        assert box and box['x'] >= 0 and box['y'] >= 0 and box['x'] + box['width'] <= width + 1 and box['y'] + box['height'] <= height + 1, (width, box)
        assert page.evaluate('document.documentElement.scrollWidth <= window.innerWidth'), width
        expect(page.get_by_role('button', name='Inventar schließen')).to_be_in_viewport()
        stores = page.locator('.inventory-store').all()
        a, b = [store.bounding_box() for store in stores]
        assert a['x'] + a['width'] <= b['x'] + 1 and abs(a['y'] - b['y']) < 1, (width, a, b)
        assert abs(a['height'] - b['height']) < 1, (width, a, b)
        measurements[width] = page.locator('.inventory-store h2').first.evaluate('(e) => parseFloat(getComputedStyle(e).fontSize)')
        if width in (1920, 3840): page.screenshot(path=str(out / f'inventory-{width}.png'))
        slot('own', 1).click(button='right')
        menu.get_by_role('button', name='Geben', exact=True).click()
        bounds = menu.bounding_box()
        assert bounds['x'] >= 0 and bounds['y'] >= 0 and bounds['x'] + bounds['width'] <= width and bounds['y'] + bounds['height'] <= height, (width, bounds)
        expect(menu.get_by_role('button', name='Jamie Parker', exact=False)).to_be_in_viewport()
        if width in (1920, 3840): page.screenshot(path=str(out / f'inventory-context-{width}.png'))
        page.keyboard.press('Escape')
        slot('own', 24).click()
        slot('own', 24).click(button='right')
        bounds = menu.bounding_box()
        assert bounds and bounds['x'] >= 0 and bounds['y'] >= 0 and bounds['x'] + bounds['width'] <= width and bounds['y'] + bounds['height'] <= height, (width, bounds)
        page.keyboard.press('Escape')
    assert measurements[3840] == 2 * measurements[1920], measurements
    page.keyboard.press('Escape')
    expect(page.locator('.inventory-shell')).not_to_be_visible()
    page.goto('http://127.0.0.1:5173/?preview=inventory', wait_until='networkidle')
    expect(page.frame_locator('iframe').locator('.inventory-shell')).to_be_visible()
    # Real typed fetch bridge: untrusted recipient responses, empty list, and give payload.
    fixture = page.frame_locator('iframe').locator('body').evaluate("async () => (await import('/src/lib/inventoryPreview.ts')).inventoryPreview()")
    game = browser.new_page(viewport={'width':1920,'height':1080})
    game.on('pageerror', lambda e: errors.append(str(e)))
    game.add_init_script('window.GetParentResourceName=()=>"rp_ui"')
    calls = []
    reply = {'ok':True, 'recipients':[{'token':'recipient-server-1','label':'Nearby player','distance':1}]}
    def route(request):
        event = request.request.url.split('/')[-1]
        if event == 'rp_inventory:recipients': request.fulfill(json=reply)
        elif event == 'rp_inventory:action':
            calls.append(request.request.post_data_json)
            request.fulfill(json={'ok':False,'error':'recipient_unavailable','inventory':fixture})
        else: request.fulfill(json={'ok':True})
    game.route('https://rp_ui/**', route)
    game.goto(url, wait_until='networkidle')
    game.evaluate('(payload)=>window.postMessage({action:"ui:open",data:{view:"inventory",payload,locked:false}},"*")', fixture)
    item = game.locator('[data-side="own"][data-slot="1"]')
    item.drag_to(game.locator('[data-side="own"][data-slot="5"]'))
    expect(game.get_by_role('status')).to_be_visible()
    assert calls[-1]['action'] == 'move' and calls[-1]['from'] == 'own' and calls[-1]['to'] == 'own'
    assert calls[-1]['slot'] == 1 and calls[-1]['target'] == 5 and calls[-1]['count'] == 4
    item.click(button='right')
    game.get_by_label('Menge', exact=True).fill('2')
    game.get_by_role('button', name='Geben', exact=True).click()
    game.get_by_role('button', name='Nearby player', exact=False).click()
    assert calls[-1]['action'] == 'give' and calls[-1]['recipient'] == 'recipient-server-1'
    assert calls[-1]['count'] == 2 and calls[-1]['ownRevision'] == fixture['own']['revision'] and 'target' not in calls[-1]
    expect(game.get_by_role('status')).to_contain_text('nicht mehr erreichbar')
    expect(item).to_have_attribute('aria-label', 'Deine Taschen, Platz 1: Mineralwasser, 4 Stück')
    reply['recipients'] = []
    item.click(button='right')
    game.get_by_role('button', name='Geben', exact=True).click()
    expect(game.get_by_label('Personen in der Nähe')).to_contain_text('Niemand')
    reply['recipients'] = [{'token':'bad','label':'Invalid distance','distance':999}]
    game.get_by_role('button', name='Geben', exact=True).click()
    expect(game.get_by_label('Personen in der Nähe')).to_contain_text('konnten nicht geladen')
    expect(game.get_by_role('button', name='Invalid distance', exact=False)).to_have_count(0)
    # Invalid late recipients cannot populate another item menu after closing.
    pending = []
    def delayed(request): pending.append(request)
    game.route('https://rp_ui/rp_inventory:recipients', delayed)
    game.get_by_role('button', name='Geben', exact=True).click()
    game.wait_for_timeout(80)
    assert pending
    game.keyboard.press('Escape')
    game.locator('[data-side="own"][data-slot="2"]').click(button='right')
    pending[0].fulfill(json={'ok':True,'recipients':[{'token':'late','label':'Old menu recipient','distance':1}]})
    game.wait_for_timeout(80)
    expect(game.get_by_role('button', name='Old menu recipient', exact=False)).to_have_count(0)
    expect(game.get_by_role('dialog')).to_contain_text('Sandwich')
    # Server snapshots control one/two panels; an empty but available stash still shows.
    single = {key: value for key, value in fixture.items() if key != 'external'}
    publish = '(payload)=>window.postMessage({action:"ui:open",data:{view:"inventory",payload,locked:false}},"*")'
    for width, height in [(1280,720),(1920,1080),(3840,2160),(3440,1440),(740,900)]:
        game.set_viewport_size({'width': width, 'height': height})
        game.evaluate(publish, single)
        expect(game.locator('.inventory-shell-single > .inventory-store')).to_have_count(1)
        expect(game.locator('[data-side="external"]')).to_have_count(0)
        box = game.locator('.inventory-shell').bounding_box()
        assert abs(box['x'] + box['width']/2 - width/2) < 2, (width, box)
        assert box['x'] >= 0 and box['x'] + box['width'] <= width and box['y'] >= 0
        expect(game.get_by_role('button', name='Inventar schließen')).to_be_in_viewport()
        if width in (1920, 3840): game.screenshot(path=str(out / f'inventory-single-{width}.png'))
        if width >= 1280:
            last_slot = game.locator('[data-side="own"][data-slot="24"]').bounding_box()
            # Only grid padding remains after the final row; no fixed-height empty footer.
            assert box['y'] + box['height'] - last_slot['y'] - last_slot['height'] < height * 0.025
        game.evaluate(publish, fixture)
        expect(game.locator('.inventory-shell > .inventory-store')).to_have_count(2)
        expect(game.locator('.inventory-shell-single')).to_have_count(0)
    empty_stash = {**fixture, 'external': {**fixture['external'], 'items': [], 'weight': 0}}
    game.evaluate(publish, empty_stash)
    expect(game.locator('.inventory-shell > .inventory-store')).to_have_count(2)
    game.evaluate(publish, single)
    expect(game.locator('.inventory-shell > .inventory-store')).to_have_count(1)
    # Slow server reply: no save banner, no grid dimming/jump, no second mutation.
    game.set_viewport_size({'width': 1920, 'height': 1080})
    game.wait_for_timeout(300)
    pending_actions = []
    game.route('https://rp_ui/rp_inventory:action', lambda request: pending_actions.append(request))
    before = game.locator('.inventory-grid').bounding_box()
    item.drag_to(game.locator('[data-side="own"][data-slot="5"]'))
    expect(item).to_be_disabled()
    expect(game.locator('.inventory-notice')).to_have_count(0)
    after = game.locator('.inventory-grid').bounding_box()
    assert before == after, (before, after)
    assert item.evaluate('(e) => getComputedStyle(e).opacity') == '1'
    assert len(pending_actions) == 1
    game.locator('[data-side="own"][data-slot="2"]').dispatch_event('click')
    assert len(pending_actions) == 1
    pending_actions[0].fulfill(json={'ok':False, 'error':'not_enough', 'inventory':single})
    expect(item).to_be_enabled()
    expect(game.locator('.inventory-notice')).to_be_visible()
    expect(item).to_contain_text('Mineralwasser')
    browser.close()
assert not errors, errors
print('PASS: centered single inventory / two available stores, cursor menu, split/merge, cross-store drag, use/drop/give/pickup, backpack, Escape/focus, 7 viewports up to 4K, studio')
