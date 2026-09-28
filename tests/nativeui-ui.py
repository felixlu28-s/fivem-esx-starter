"""Real renderer + NUI contract. Run with Vite, Playwright and installed Chrome."""
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

out = Path('.codex-log')
out.mkdir(exist_ok=True)
errors = []
with sync_playwright() as p:
    browser = p.chromium.launch(channel='chrome', headless=True)
    page = browser.new_page(viewport={'width': 1920, 'height': 1080})
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.goto('http://127.0.0.1:5173/?view=nativeui', wait_until='networkidle')
    selected = page.locator('.native-row.is-selected')

    def choose(item):
        for _ in range(12):
            if selected.get_attribute('data-item') == item:
                return
            page.keyboard.press('ArrowDown')
        raise AssertionError('Item not found: ' + item)

    expect(selected).to_have_attribute('data-item', 'action')
    page.locator('[data-item=settings]').click()
    page.locator('[data-item=gps]').hover()
    page.mouse.wheel(0, 700)
    page.keyboard.press('Tab')
    page.keyboard.press('s')
    expect(selected).to_have_attribute('data-item', 'action')
    page.keyboard.press('Enter')
    expect(selected.locator('.native-row-value')).to_have_text('1')
    page.keyboard.press('ArrowDown')
    page.keyboard.press('ArrowLeft')
    expect(selected.locator('.native-row-value')).to_have_text('Shop')
    page.keyboard.press('ArrowRight')
    expect(selected.locator('.native-row-value')).to_have_text('Keine')
    page.keyboard.press('ArrowRight')
    expect(selected.locator('.native-row-value')).to_have_text('Flughafen')
    choose('notifications')
    expect(selected).to_have_attribute('aria-checked', 'true')
    page.keyboard.press('Enter')
    expect(selected).to_have_attribute('aria-checked', 'false')
    choose('settings')
    page.keyboard.press('Enter')
    expect(page.locator('.native-menu')).to_have_class('native-menu native-theme-mint')
    page.keyboard.press('ArrowDown')
    page.keyboard.press('Enter')
    expect(page.locator('.native-subtitle')).to_contain_text('WEITERE OPTIONEN')
    page.keyboard.press('Backspace')
    expect(selected).to_have_attribute('data-item', 'nested')
    page.keyboard.press('Backspace')
    expect(selected).to_have_attribute('data-item', 'settings')
    choose('dynamic')
    page.keyboard.press('Enter')
    expect(page.locator('.native-row')).to_have_count(4)
    page.keyboard.press('Backspace')
    choose('locked')
    page.keyboard.press('Enter')
    expect(selected).to_have_attribute('aria-disabled', 'true')
    expect(page.locator('.native-subtitle')).to_contain_text('INTERAKTIONSMENÜ')
    choose('reject')
    page.keyboard.press('Enter')
    expect(selected).to_have_attribute('aria-checked', 'false')
    choose('empty')
    expect(page.locator('.native-row')).to_have_count(7)
    page.keyboard.press('Enter')
    expect(page.locator('.native-empty')).to_be_visible()
    page.keyboard.press('ArrowUp')
    page.keyboard.press('Enter')
    expect(page.locator('.native-subtitle')).to_contain_text('0 / 0')
    page.keyboard.press('Backspace')
    choose('replace')
    page.keyboard.press('Enter')
    expect(page.locator('.native-subtitle')).to_contain_text('NEUES HAUPTMENÜ')
    page.keyboard.press('Backspace')
    expect(page.locator('.native-menu')).to_have_count(0)

    for width, height in [(1280, 720), (1920, 1080), (2560, 1440), (3840, 2160), (3440, 1440), (740, 900)]:
        page.set_viewport_size({'width': width, 'height': height})
        page.goto('http://127.0.0.1:5173/?view=nativeui', wait_until='networkidle')
        bounds = page.locator('.native-menu').bounding_box()
        assert bounds['x'] >= 0 and bounds['x'] + bounds['width'] <= width
        assert bounds['y'] >= 0 and bounds['y'] + bounds['height'] <= height
        if width == 3840:
            assert abs(bounds['width'] - 800) < 0.1, bounds
        page.screenshot(path=str(out / f'nativeui-{width}x{height}.png'))

    # Global selection guard leaves editable content intact on other real views.
    page.goto('http://127.0.0.1:5173/?view=creator', wait_until='networkidle')
    page.keyboard.press('Control+a')
    assert page.evaluate('window.getSelection().toString()') == ''
    assert page.locator('h1').first.evaluate('(el) => getComputedStyle(el).userSelect') == 'none'
    field = page.locator('input:not([type]), input[type=text]').first
    field.fill('Testname')
    field.press('Control+a')
    assert field.evaluate('(el) => el.selectionStart === 0 && el.selectionEnd === el.value.length')
    field.press('Backspace')
    expect(field).to_have_value('')

    # Studio preview takes keyboard focus and reports closing its root level.
    page.goto('http://127.0.0.1:5173/?preview=nativeui', wait_until='networkidle')
    expect(page.frame_locator('iframe').locator('.native-menu')).to_be_visible()
    page.keyboard.press('ArrowDown')
    expect(page.frame_locator('iframe').locator('.is-selected')).to_have_attribute('data-item', 'gps')
    page.keyboard.press('Escape')
    expect(page.locator('iframe')).to_have_count(0)

    game = browser.new_context(viewport={'width': 1920, 'height': 1080})
    game.add_init_script("""
      window.GetParentResourceName = () => 'rp_ui';
      window.requests = [];
      window.fetch = (url, options) => {
        if (String(url).endsWith('/rp_nativeui:input')) return new Promise(resolve => {
          window.requests.push(JSON.parse(options.body));
          window.answer = result => resolve(new Response(JSON.stringify(result)));
        });
        return Promise.resolve(new Response(JSON.stringify({ok: true})));
      };
    """)
    client = game.new_page()
    client.on('pageerror', lambda error: errors.append(str(error)))
    client.goto('http://127.0.0.1:5173/?view=nativeui', wait_until='networkidle')
    # Persistent overlay components may remain mounted while visually unavailable.
    expect(client.locator('.native-menu')).to_have_count(0)
    # Playwright's hidden check ignores opacity and off-screen transforms.
    expect(client.locator('.phone-device')).to_have_css('opacity', '0')
    expect(client.locator('.phone-device')).not_to_be_in_viewport()
    client.evaluate("""async () => {
      const {nativePreview} = await import('/src/lib/nativePreview.ts');
      window.menu = {...nativePreview(), session:'game', revision:1};
      window.postMessage({action:'ui:open', data:{view:'nativeui',payload:window.menu,locked:true}}, '*');
    }""")
    expect(client.locator('.native-menu')).to_be_visible()
    client.keyboard.press('ArrowDown')
    client.keyboard.press('Enter')
    assert client.evaluate('requests.length') == 1, 'Only one input in flight'
    assert client.evaluate('requests[0]') == {'key': 'down', 'session': 'game', 'revision': 1}
    client.evaluate("""() => {
      window.menu = {...window.menu,revision:3,selected:3};
      window.postMessage({action:'ui:open',data:{view:'nativeui',payload:window.menu,locked:true}}, '*');
    }""")
    expect(client.locator('.is-selected')).to_have_attribute('data-item', 'notifications')
    client.evaluate("window.answer({ok:true,nativeui:{...window.menu,revision:2,selected:2}})")
    expect(client.locator('[role=menu]')).to_have_attribute('aria-busy', 'false')
    expect(client.locator('.is-selected')).to_have_attribute('data-item', 'notifications')
    client.evaluate("window.postMessage({action:'ui:open',data:{view:'nativeui',payload:{...window.menu,items:[{type:'list'}]},locked:true}}, '*')")
    expect(client.locator('.is-selected')).to_have_attribute('data-item', 'notifications')
    client.keyboard.press('Enter')
    client.evaluate("window.answer({ok:false,error:'action_rejected',nativeui:window.menu})")
    expect(client.locator('[role=menu]')).to_have_attribute('aria-busy', 'false')
    expect(client.locator('.is-selected')).to_have_attribute('aria-checked', 'true')
    client.keyboard.press('Backspace')
    client.evaluate("window.answer({ok:true,closed:true})")
    expect(client.locator('.native-menu')).to_have_count(0)
    browser.close()
assert not errors, errors
print('PASS: NativeUI keyboard-only navigation, lists, checkboxes, nested/back/empty/dynamic menus, 6 layouts through 4K, text selection, Studio focus, NUI ordering and validation')
