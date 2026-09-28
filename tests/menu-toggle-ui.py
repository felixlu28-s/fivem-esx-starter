"""Menu toggle regression checks with Vite, Playwright and Chrome."""
from playwright.sync_api import sync_playwright, expect

errors = []
with sync_playwright() as p:
    browser = p.chromium.launch(channel='chrome', headless=True)
    page = browser.new_page(viewport={'width': 1920, 'height': 1080})
    page.on('pageerror', lambda error: errors.append(str(error)))
    def show(view):
        page.goto(f'http://127.0.0.1:5173/?view={view}', wait_until='networkidle')
    for view, key in [('me', 'm'), ('inventory', 'i'), ('shop', 'e'), ('crafting', 'e'), ('settings', 'F12')]:
        show(view)
        page.keyboard.press(key)
        expect(page.locator('#root')).to_be_empty()
    show('shop')
    search = page.get_by_label('Artikel suchen')
    search.fill('')
    search.press('e')
    expect(search).to_have_value('e')
    page.locator('h1').click()
    page.keyboard.press('Control+e')
    expect(page.locator('.commerce-shell')).to_be_visible()
    page.evaluate('window.dispatchEvent(new KeyboardEvent("keydown", {key:"e",code:"KeyE",repeat:true}))')
    expect(page.locator('.commerce-shell')).to_be_visible()
    page.keyboard.press('e')
    expect(page.locator('#root')).to_be_empty()

    # Persisted project mappings are used by browser menus, too.
    show('settings')
    def rebind(action, key):
        page.locator(f'[data-action="{action}"]').click()
        page.get_by_role('button', name='Neu belegen', exact=True).click()
        page.locator(f'[data-key="{key}"]').click()
    rebind('rp_inventory:open', 'J')
    rebind('rp_player:me', 'K')
    rebind('rp_commerce:interact', 'L')
    rebind('rp_ui:settings', 'F10')
    page.keyboard.press('F12')
    expect(page.locator('.settings')).to_be_visible()
    page.keyboard.press('F10')
    expect(page.locator('#root')).to_be_empty()
    for view, old, new in [('inventory','i','j'),('me','m','k'),('shop','e','l'),('crafting','e','l')]:
        show(view)
        page.keyboard.press(old)
        expect(page.locator('#root')).not_to_be_empty()
        page.keyboard.press(new)
        expect(page.locator('#root')).to_be_empty()

    show('settings')
    rebind('rp_ui:settings', 'J')
    dialog = page.get_by_role('dialog')
    dialog.get_by_role('button', name='Überschreiben & belegen').click()
    page.keyboard.press('j')
    expect(dialog.get_by_role('heading')).to_have_text('Aktionen ohne Taste')
    page.keyboard.press('j')
    expect(dialog).to_be_visible()
    dialog.get_by_role('button', name='Abbrechen', exact=True).click()
    page.get_by_role('button', name='Neu belegen', exact=True).click()
    page.keyboard.press('j')
    expect(page.locator('.settings')).to_be_visible()
    expect(page.get_by_role('button', name='Neu belegen', exact=True)).to_be_visible()
    page.keyboard.press('j')
    dialog.get_by_role('button', name='Trotzdem schließen').click()
    expect(page.locator('#root')).to_be_empty()

    # NUI close is acknowledged; rejected closes retain the view, and repeat events do not close it.
    context = browser.new_context()
    context.add_init_script("window.GetParentResourceName=()=> 'rp_ui'")
    requests = []
    allow = False
    def route(request):
        requests.append(request.request.url)
        request.fulfill(json={'ok': allow})
    context.route('https://rp_ui/**', route)
    game = context.new_page()
    game.goto('http://127.0.0.1:5173/', wait_until='networkidle')
    game.evaluate('window.postMessage({action:"ui:open",data:{view:"welcome",locked:false,toggleKey:"J",payload:{}}},"*")')
    expect(game.locator('.fallback')).to_be_visible()
    with game.expect_response('https://rp_ui/ui:close'):
        game.keyboard.press('j')
    game.wait_for_timeout(100)
    expect(game.locator('.fallback')).to_be_visible()
    allow = True
    game.keyboard.press('j')
    expect(game.locator('#root')).to_be_empty()
    assert any(url.endswith('/ui:close') for url in requests)
    browser.close()
assert not errors, errors
print('PASS: M/I/F12/E toggles, custom bindings, repeat/modifier/input guards, settings warning and rebind cancellation, acknowledged NUI close')
