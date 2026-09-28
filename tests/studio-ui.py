"""Browser Studio smoke test. Requires npm run ui:preview, Playwright and Chrome."""
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

out = Path('.codex-log')
out.mkdir(exist_ok=True)
errors = []
with sync_playwright() as p:
    browser = p.chromium.launch(channel='chrome', headless=True)
    page = browser.new_page(viewport={'width': 1920, 'height': 1080})
    page.set_default_timeout(10000)
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.goto('http://127.0.0.1:5173/', wait_until='networkidle')
    toggle = lambda value: page.locator(f'[data-screen="{value}"]')
    preview = lambda: page.frame_locator('iframe')
    expect(page.get_by_role('navigation', name='Verfügbare Oberflächen')).to_be_visible()
    expect(toggle('me')).to_have_attribute('aria-pressed', 'true')
    expect(preview().get_by_role('heading', name='Alex Morgan')).to_be_visible()
    page.screenshot(path=str(out / 'studio-me.png'))

    # Toggle selected view off, then on; closing the real UI updates the sidebar.
    toggle('me').click()
    expect(page.locator('iframe')).to_have_count(0)
    expect(page.get_by_role('heading', name='Die Bühne gehört dir.')).to_be_visible()
    toggle('me').click()
    preview().get_by_role('button', name='Menü schließen').click()
    expect(toggle('me')).to_have_attribute('aria-pressed', 'false')
    expect(page.locator('iframe')).to_have_count(0)

    # All registered screens use their actual application components.
    for name, selector in [('hud', '.game-hud'), ('interaction', '.interaction-prompt'), ('characters', '.selection-intro'), ('creator', 'input[type=date]'),
                           ('loading', '.arrival-status'), ('error', '.arrival-status'),
                           ('inventory', '.inventory-shell'), ('shop', '.commerce-shell'), ('crafting', '.commerce-shell'), ('nativeui', '.native-menu'),
                           ('welcome', '.fallback'), ('organizations', '.organizations'), ('settings', '.keyboard')]:
        toggle(name).click()
        expect(preview().locator(selector)).to_be_visible()
        expect(page.locator('[data-screen][aria-pressed=true]')).to_have_count(1)

    # Fixed viewport retains real CSS dimensions, independent of display scale.
    page.get_by_label('Auflösung', exact=True).select_option('fullhd')
    expect(page.locator('iframe')).to_have_css('width', '1920px')
    expect(page.locator('iframe')).to_have_css('height', '1080px')
    assert page.frames[1].evaluate('window.innerWidth') == 1920
    page.get_by_label('Hintergrund', exact=True).select_option('checker')
    expect(page.locator('.studio-frame')).to_have_class('studio-frame studio-background-checker')
    page.screenshot(path=str(out / 'studio-settings.png'))

    # Rebinding is interactive; reset clears only browser demo preferences.
    preview().locator('[data-action="rp_player:me"]').click()
    preview().get_by_role('button', name='Neu belegen').click()
    preview().locator('[data-key="J"]').click()
    expect(preview().locator('[data-action="rp_player:me"] kbd')).to_have_text('J')
    page.get_by_role('button', name='Demozustand zurücksetzen').click()
    expect(preview().locator('[data-action="rp_player:me"] kbd')).to_have_text('M')

    # Foreign visibility messages must not hide an active iframe.
    page.evaluate("window.postMessage({action:'studio:visibility',visible:false}, location.origin)")
    expect(toggle('settings')).to_have_attribute('aria-pressed', 'true')
    page.get_by_role('button', name='UI ausblenden', exact=True).click()
    expect(page.locator('iframe')).to_have_count(0)
    page.get_by_label('UI suchen', exact=True).fill('Fitness')
    expect(page.locator('[data-screen]')).to_have_count(1)
    expect(toggle('me')).to_be_visible()
    page.get_by_label('UI suchen', exact=True).fill('unbekannte oberfläche')
    expect(page.get_by_text('Keine passende Oberfläche gefunden.')).to_be_visible()
    page.get_by_label('UI suchen', exact=True).fill('')

    # Query can reopen a specific view; standalone link remains available.
    page.goto('http://127.0.0.1:5173/?preview=creator', wait_until='networkidle')
    expect(toggle('creator')).to_have_attribute('aria-pressed', 'true')
    expect(page.get_by_role('link', name='Einzeln öffnen')).to_have_attribute('href', './?view=creator')
    for width, height in [(1366, 768), (1280, 720), (740, 900)]:
        page.set_viewport_size({'width': width, 'height': height})
        page.get_by_label('Auflösung', exact=True).select_option('auto')
        expect(page.locator('iframe')).to_be_visible()
        assert page.locator('body').evaluate('(e) => e.scrollWidth <= window.innerWidth')
        page.screenshot(path=str(out / f'studio-{width}x{height}.png'))

    # In FiveM, the browser-only studio cannot appear even with its URL flag.
    game = browser.new_context()
    game.add_init_script("window.GetParentResourceName = () => 'rp_ui';")
    game.route('https://rp_ui/**', lambda route: route.fulfill(json={'ok': True}))
    client = game.new_page()
    client.on('pageerror', lambda error: errors.append(str(error)))
    client.goto('http://127.0.0.1:5173/?preview=creator', wait_until='networkidle')
    expect(client.locator('.studio-shell')).to_have_count(0)
    expect(client.locator('iframe')).to_have_count(0)
    expect(client.locator('#root')).to_be_empty()
    browser.close()
assert not errors, errors
print('PASS: 14 studio screens, visibility toggles, inner close, viewport scaling, backgrounds, interactive binding/reset, message source checks, search, direct links, responsive layouts, FiveM exclusion')
