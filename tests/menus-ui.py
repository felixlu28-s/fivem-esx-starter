"""Run with Vite on 127.0.0.1:5173 and Playwright + Chrome installed."""
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

out = Path('.codex-log')
out.mkdir(exist_ok=True)
errors = []
with sync_playwright() as p:
    browser = p.chromium.launch(channel='chrome', headless=True)
    page = browser.new_page(viewport={'width': 1920, 'height': 1080})
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.goto('http://127.0.0.1:5173/?view=settings', wait_until='networkidle')
    page.evaluate('localStorage.clear()')
    page.reload(wait_until='networkidle')
    key = lambda value: page.locator(f'[data-key="{value}"]')
    action = lambda value: page.locator(f'[data-action="{value}"]')
    expect(action('rp_player:me')).to_have_attribute('aria-pressed', 'true')
    expect(key('M')).to_have_attribute('aria-pressed', 'true')
    assert page.locator('.keyboard-key').count() == 102
    page.screenshot(path=str(out / 'settings-default.png'))

    # Only custom systems are listed; GTA movement does not occupy keys here.
    expect(page.locator('[data-action]')).to_have_count(4)
    action('rp_ui:settings').click()
    expect(key('F12')).to_have_attribute('aria-pressed', 'true')
    key('M').click()
    expect(action('rp_player:me')).to_have_attribute('aria-pressed', 'true')
    page.get_by_role('button', name='Neu belegen').click()
    expect(key('J')).to_have_class('keyboard-key key-free ')
    assert 'key-free' in key('W').get_attribute('class')
    assert 'key-occupied' in key('F12').get_attribute('class')
    expect(key('F8')).to_be_disabled()
    page.screenshot(path=str(out / 'settings-rebind.png'))
    key('J').click()
    expect(action('rp_player:me').locator('kbd')).to_have_text('J')
    page.reload(wait_until='networkidle')
    expect(action('rp_player:me').locator('kbd')).to_have_text('J')

    # Old browser snapshots cannot reintroduce GTA actions; own preferences stay.
    page.evaluate("""() => {
        const saved = JSON.parse(localStorage.getItem('rp-input-preview'));
        saved.actions.push({id:'rp_move:forward',label:'Vorwärts',category:'Bewegung',description:'Vorwärts',key:'W',defaultKey:'W',context:'foot'});
        localStorage.setItem('rp-input-preview', JSON.stringify(saved));
    }""")
    page.reload(wait_until='networkidle')
    expect(page.locator('[data-action]')).to_have_count(4)
    expect(action('rp_player:me').locator('kbd')).to_have_text('J')

    # Conflict cancellation changes nothing; confirmation clears every old action.
    page.get_by_role('button', name='Neu belegen').click()
    key('F12').click()
    dialog = page.get_by_role('dialog')
    expect(dialog).to_be_visible()
    expect(dialog.locator('li')).to_have_count(1)
    expect(dialog.locator('li')).to_have_text('Einstellungen')
    page.screenshot(path=str(out / 'settings-conflict.png'))
    dialog.get_by_role('button', name='Abbrechen').click()
    expect(action('rp_player:me').locator('kbd')).to_have_text('J')
    key('F12').click()
    dialog.get_by_role('button', name='Überschreiben & belegen').click()
    expect(action('rp_player:me').locator('kbd')).to_have_text('F12')
    expect(action('rp_ui:settings').locator('kbd')).to_have_text('Nicht belegt')
    page.get_by_role('button', name='Einstellungen schließen', exact=True).click()
    expect(dialog.get_by_role('heading')).to_have_text('Aktionen ohne Taste')
    expect(dialog.locator('li')).to_have_count(1)
    page.screenshot(path=str(out / 'settings-close-warning.png'))
    page.keyboard.press('Escape')
    expect(dialog).not_to_be_visible()
    expect(page.get_by_role('main', name='Einstellungen')).to_be_visible()
    page.keyboard.press('Escape')
    dialog.get_by_role('button', name='Trotzdem schließen').click()
    expect(page.get_by_role('main')).not_to_be_visible()

    # Reset recovers both custom menu defaults.
    page.goto('http://127.0.0.1:5173/?view=settings', wait_until='networkidle')
    page.get_by_role('button', name='Standard wiederherstellen', exact=True).click()
    dialog.get_by_role('button', name='Wiederherstellen', exact=True).click()
    expect(action('rp_player:me').locator('kbd')).to_have_text('M')
    expect(action('rp_ui:settings').locator('kbd')).to_have_text('F12')
    page.keyboard.press('Escape')
    expect(page.get_by_role('main')).not_to_be_visible()

    for width, height in [(1920, 1080), (1366, 768), (1280, 720), (740, 900)]:
        page.set_viewport_size({'width': width, 'height': height})
        for view in ['settings', 'me']:
            page.goto(f'http://127.0.0.1:5173/?view={view}', wait_until='networkidle')
            expect(page.get_by_role('main')).to_be_visible()
            assert page.locator('body').evaluate('(e) => e.scrollWidth <= window.innerWidth')
            assert page.locator('.menu-shell').evaluate('(e) => e.scrollWidth <= e.clientWidth + 1')
            if view == 'settings':
                key('M').scroll_into_view_if_needed()
                page.get_by_role('button', name='Neu belegen').click()
                key('J').click()
                expect(action('rp_player:me').locator('kbd')).to_have_text('J')
                page.evaluate('localStorage.clear()')
            else:
                expect(page.get_by_role('heading', name='Alex Morgan')).to_be_visible()
                expect(page.get_by_role('progressbar')).to_have_attribute('aria-valuenow', '42')
                page.get_by_role('button', name='Werte aktualisieren').click()
            page.screenshot(path=str(out / f'{view}-{width}x{height}.png'))
    browser.close()
assert not errors, errors
print('PASS: 4 custom actions, 102 keys, legacy snapshot migration, persisted binding, conflict/cancel/confirm, close warnings, reset, Me fitness, 4 viewport sizes; no browser errors')
