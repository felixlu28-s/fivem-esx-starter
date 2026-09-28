"""HUD browser and simulated NUI checks; requires Vite, Playwright and Chrome."""
from playwright.sync_api import sync_playwright, expect

errors = []
with sync_playwright() as p:
    browser = p.chromium.launch(channel='chrome', headless=True)
    page = browser.new_page(viewport={'width': 1920, 'height': 1080})
    page.on('pageerror', lambda error: errors.append(str(error)))
    for width, height in [(1280, 720), (1920, 1080), (3840, 2160), (3440, 1440), (740, 900)]:
        page.set_viewport_size({'width': width, 'height': height})
        page.goto('http://127.0.0.1:5173/?view=hud', wait_until='networkidle')
        hud = page.locator('.game-hud')
        expect(hud).to_be_visible()
        box = hud.bounding_box()
        assert box['x'] > width / 2 and box['y'] < height / 5, box
        assert box['x'] + box['width'] <= width and box['y'] + box['height'] <= height
        assert hud.evaluate('(e)=>getComputedStyle(e).pointerEvents') == 'none'
        assert page.locator('body').evaluate('(e)=>e.scrollWidth <= innerWidth')
        expect(page.locator('.hud-cash strong')).to_contain_text('2.450')
    page.set_viewport_size({'width': 1920, 'height': 1080})
    page.goto('http://127.0.0.1:5173/?preview=hud', wait_until='networkidle')
    page.get_by_label('Hintergrund', exact=True).select_option('gta')
    page.screenshot(path='.codex-log/hud-studio.png')

    context = browser.new_context(viewport={'width': 1920, 'height': 1080})
    context.add_init_script("window.GetParentResourceName = () => 'rp_ui'")
    context.route('https://rp_ui/**', lambda route: route.fulfill(json={'ok': True}))
    game = context.new_page()
    game.on('pageerror', lambda error: errors.append(str(error)))
    game.goto('http://127.0.0.1:5173/', wait_until='networkidle')
    def send(value):
        game.evaluate('(value)=>window.postMessage(value,"*")', value)
    data = dict(cash=0, id=7, players=123, connected=True, talking=False, range=1.5, inset=0.05)
    send({'action': 'ui:hud', 'data': data})
    expect(game.locator('.hud-cash strong')).to_have_text('$ 0')
    expect(game.locator('.hud-range')).to_have_text('1,5 m')
    expect(game.locator('.hud-id')).to_have_text('ID 7')
    data.update(cash=999999999, talking=True)
    send({'action': 'ui:hud', 'data': data})
    expect(game.locator('.hud-voice')).to_have_class('hud-voice is-talking')
    expect(game.locator('.hud-voice-status')).to_have_text('Spricht')
    for invalid in [dict(data, cash=-1), dict(data, id='bad'), dict(data, connected=False), dict(data, range=-1), dict(data, inset=10)]:
        send({'action': 'ui:hud', 'data': invalid})
    expect(game.locator('.hud-voice-status')).to_have_text('Spricht')
    send({'action': 'ui:interaction', 'data': dict(label='Shop', verb='Einkaufen', key='E', icon='shop')})
    expect(game.locator('.game-hud')).to_be_visible()
    expect(game.locator('.interaction-prompt')).to_be_visible()
    send({'action': 'ui:open', 'data': dict(view='welcome', locked=False, payload={})})
    expect(game.locator('.game-hud')).to_have_count(0)
    send({'action': 'ui:close'})
    expect(game.locator('.game-hud')).to_be_visible()
    data.update(connected=False, talking=False, range=False, cash=False, players=False)
    send({'action': 'ui:hud', 'data': data})
    expect(game.locator('.hud-voice-status')).to_have_text('Offline')
    expect(game.locator('.hud-cash strong')).to_have_text('—')
    send({'action': 'ui:hud', 'data': False})
    expect(game.locator('.game-hud')).to_have_count(0)
    expect(game.locator('.interaction-prompt')).to_be_visible()
    browser.close()
assert not errors, errors
print('PASS: HUD at five resolutions, safe area, NUI payload validation, live money/voice, offline state, menu hiding and interaction coexistence')
