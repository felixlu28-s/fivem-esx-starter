"""Interactive organization UI regression. Vite on 5173, Playwright + Chrome."""
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

errors = []
out = Path('.codex-log')
out.mkdir(exist_ok=True)
with sync_playwright() as p:
    browser = p.chromium.launch(channel='chrome', headless=True)
    page = browser.new_page(viewport={'width': 1920, 'height': 1080})
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.goto('http://127.0.0.1:5173/?view=me', wait_until='networkidle')
    page.get_by_role('button', name='Organisationen').click()
    expect(page.get_by_role('main', name='Organisationsverwaltung')).to_be_visible()
    expect(page.get_by_role('heading', name='Los Santos Police Department')).to_be_visible()
    offline = page.get_by_role('row').filter(has_text='Sam Rivera')
    expect(offline.get_by_role('button', name='Entfernen')).to_be_disabled()
    page.get_by_label('Rang von Jamie Parker').select_option('1')
    page.get_by_role('row').filter(has_text='Jamie Parker').get_by_role('button', name='Rang ändern').click()
    expect(page.get_by_role('dialog')).to_be_visible()
    page.keyboard.press('Escape')
    expect(page.get_by_role('dialog')).to_have_count(0)
    expect(page.locator('.organizations')).to_be_visible()
    page.get_by_role('row').filter(has_text='Jamie Parker').get_by_role('button', name='Rang ändern').click()
    page.get_by_role('button', name='Bestätigen').click()
    expect(page.get_by_label('Rang von Jamie Parker')).to_have_value('1')
    page.get_by_label('Charakter aufnehmen', exact=True).select_option('12')
    page.get_by_role('button', name='Aufnehmen').click()
    page.get_by_role('button', name='Bestätigen').click()
    expect(page.get_by_role('row').filter(has_text='Taylor Brooks')).to_be_visible()
    page.get_by_role('button', name='Finanzen', exact=True).click()
    before = page.locator('.organization-funds > strong').inner_text()
    page.get_by_label('Betrag ($)').fill('250')
    page.get_by_role('button', name='Einzahlen', exact=True).click()
    page.get_by_role('button', name='Abbrechen', exact=True).click()
    expect(page.locator('.organization-funds > strong')).to_have_text(before)
    page.get_by_role('button', name='Einzahlen', exact=True).click()
    page.get_by_role('button', name='Bestätigen').click()
    expect(page.locator('.organization-funds > strong')).to_contain_text('48.750')
    page.get_by_role('button', name='Ränge', exact=True).click()
    first = page.locator('.organization-ranks form').first
    first.get_by_label('Bezeichnung').fill('Anwärter')
    first.get_by_label('Gehalt ($)').fill('350')
    first.get_by_role('button', name='Speichern').click()
    expect(page.locator('.organization-ranks form').first.get_by_label('Bezeichnung')).to_have_value('Anwärter')
    page.get_by_role('button', name='+ Organisation anlegen').click()
    dialog = page.get_by_role('dialog')
    dialog.get_by_label('Art', exact=True).select_option('faction')
    dialog.get_by_label('Bezeichnung').fill('Hafenclub')
    dialog.get_by_label('Interne Kennung').fill('hafenclub')
    dialog.get_by_role('button', name='Anlegen').click()
    expect(page.get_by_role('heading', name='Hafenclub', exact=True)).to_be_visible()
    expect(page.get_by_role('button', name='Finanzen', exact=True)).to_have_count(0)
    page.get_by_role('button', name='Einstellungen', exact=True).click()
    page.locator('.organization-body').get_by_label('Bezeichnung').fill('Hafencrew')
    page.get_by_role('button', name='Bezeichnung speichern').click()
    expect(page.get_by_role('heading', name='Hafencrew', exact=True)).to_be_visible()

    # Standard view must scale with resolution and remain scrollable on narrow displays.
    for width, height in [(1280, 720), (1920, 1080), (3840, 2160), (740, 900)]:
        page.set_viewport_size({'width': width, 'height': height})
        page.goto('http://127.0.0.1:5173/?view=organizations', wait_until='networkidle')
        expect(page.get_by_role('button', name='Aktualisieren')).to_be_visible()
        assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
        bounds = page.locator('.organizations').bounding_box()
        assert bounds['y'] >= 0 and bounds['y'] + bounds['height'] <= height + 1
        if width == 3840:
            assert page.locator('.menu-header h1').evaluate('(e)=>parseFloat(getComputedStyle(e).fontSize)') >= 60
        page.screenshot(path=str(out / f'organizations-{width}.png'))

    # A real NUI payload decides role visibility; browser-only admin demos never grant privileges.
    context = browser.new_context(viewport={'width': 1920, 'height': 1080})
    context.add_init_script("window.GetParentResourceName = () => 'rp_ui'")
    context.route('https://rp_ui/**', lambda route: route.fulfill(json={'ok': True}))
    game = context.new_page()
    game.on('pageerror', lambda error: errors.append(str(error)))
    game.goto('http://127.0.0.1:5173/?view=organizations', wait_until='networkidle')
    expect(game.locator('#root')).to_be_empty()
    payload = {'admin': False, 'character': 'Test Character', 'selected': 'job:police', 'memberLimit': 200,
               'list': [{'kind': 'job', 'name': 'police', 'label': 'Police', 'grades': [{'grade': 0, 'name': 'recruit', 'label': 'Recruit', 'salary': 100}],
                         'manage': False, 'own': True, 'duty': False, 'finance': False}], 'members': [], 'candidates': []}
    game.evaluate("p => window.postMessage({action:'ui:open',data:{view:'organizations',payload:p,locked:false}},'*')", payload)
    expect(game.get_by_role('heading', name='Police', exact=True)).to_be_visible()
    expect(game.get_by_role('button', name='+ Organisation anlegen')).to_have_count(0)
    expect(game.get_by_role('button', name='Aufnehmen')).to_have_count(0)
    expect(game.get_by_role('button', name='Dienst beginnen')).to_be_visible()
    game.get_by_role('button', name='Finanzen', exact=True).click()
    expect(game.get_by_role('button', name='Auszahlen', exact=True)).to_have_count(0)
    game.keyboard.press('Escape')
    expect(game.locator('#root')).to_be_empty()
    browser.close()
assert not errors, errors
print('PASS: M menu, organizations, ranks, members, confirmation/cancel, finance, faction creation, role visibility, responsive HD/4K/narrow views')
