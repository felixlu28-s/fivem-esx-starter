"""Optional browser check: pip install playwright; python tests/ui-smoke.py."""
from pathlib import Path
from playwright.sync_api import sync_playwright

out = Path('.codex-log')
out.mkdir(exist_ok=True)
errors = []
with sync_playwright() as p:
    browser = p.chromium.launch(channel='chrome', headless=True)
    page = browser.new_page(viewport={'width': 1920, 'height': 1080})
    page.set_default_timeout(10000)
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.goto('http://127.0.0.1:5173/?view=characters', wait_until='networkidle')
    page.locator('.selection-intro h1').wait_for()
    page.screenshot(path=str(out / 'character-selection.png'))
    page.locator('.empty-card').first.click()
    page.get_by_label('Vorname', exact=True).fill('Jörg')
    page.get_by_label('Nachname', exact=True).fill('Morgan')
    page.locator('input[type=date]').fill('1998-06-14')
    page.screenshot(path=str(out / 'character-creator-identity.png'))
    page.get_by_role('button', name='Weiter').click()
    page.get_by_label('Mutter', exact=True).select_option('23')
    page.get_by_role('button', name='04 Haare').click()
    page.get_by_label('Frisur', exact=True).fill('24')
    page.screenshot(path=str(out / 'character-creator-hair.png'))
    page.get_by_role('button', name='07 Accessoires').click()
    page.get_by_role('button', name='Einreisen').click()
    page.locator('.arrival-status').wait_for()
    for width, height in [(1366, 768), (1280, 720), (740, 900)]:
        page.set_viewport_size({'width': width, 'height': height})
        page.goto('http://127.0.0.1:5173/?view=creator', wait_until='networkidle')
        assert page.get_by_role('button', name='Weiter').is_visible()
        assert page.locator('body').evaluate('(e) => e.scrollWidth <= window.innerWidth')
        page.screenshot(path=str(out / f'creator-{width}x{height}.png'))
    browser.close()
assert not errors, errors
print('PASS: selection, creator identity, appearance controls, submit, 3 viewport sizes; no browser exceptions')
