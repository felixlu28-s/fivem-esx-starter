"""Real loading entry: native progress, early events, fade, Studio, responsive layout.
Run with Vite on 127.0.0.1:5173 and Playwright + Chrome installed.
"""
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

Path('.codex-log').mkdir(exist_ok=True)
with sync_playwright() as p:
    browser = p.chromium.launch(channel='chrome', headless=True)
    page = browser.new_page(viewport={'width': 1920, 'height': 1080})
    errors = []
    page.on('pageerror', lambda e: errors.append(str(e)))
    def send(data):
        page.evaluate("data => window.postMessage(data, '*')", data)
    page.goto('http://127.0.0.1:5173/loading.html', wait_until='networkidle')
    bar = page.get_by_role('progressbar')
    expect(bar).not_to_have_attribute('aria-valuenow')
    page.wait_for_timeout(1100)
    expect(bar).not_to_have_attribute('aria-valuenow')  # No fabricated live progress.
    send({'eventName': 'loadProgress', 'loadFraction': 0.42})
    expect(bar).to_have_attribute('aria-valuenow', '42')
    for payload in [None, [], {'eventName': 'loadProgress', 'loadFraction': '1'},
                    {'eventName': 'loadProgress', 'loadFraction': .1},
                    {'action': 'ui:loading', 'data': {'phase': '<script>evil</script>'}}]:
        send(payload)
    expect(bar).to_have_attribute('aria-valuenow', '42')
    page.evaluate("window.postMessage({eventName:'loadProgress',loadFraction:NaN}, '*')")
    expect(bar).to_have_attribute('aria-valuenow', '42')
    for width, height in [(1280,720), (1920,1080), (3840,2160), (3440,1440), (740,900), (480,650)]:
        page.set_viewport_size({'width': width, 'height': height})
        for selector in ['.join-brand', '.join-intro h1', '.join-tip', '.join-loading']:
            rect = page.locator(selector).bounding_box()
            assert rect['x'] >= 0 and rect['y'] >= 0, (width, selector, rect)
            assert rect['x'] + rect['width'] <= width + 1 and rect['y'] + rect['height'] <= height + 1, (width, selector, rect)
        assert page.locator('.join-intro').bounding_box()['y'] + page.locator('.join-intro').bounding_box()['height'] <= page.locator('.join-footer').bounding_box()['y'] + 1
        assert page.locator('.join-art').evaluate('(img) => img.complete && img.naturalWidth > 1000')
        page.screenshot(path=f'.codex-log/loading-{width}.png')
    page.set_viewport_size({'width':1920,'height':1080})
    send({'eventName':'loadProgress','loadFraction':1.2})
    expect(bar).to_have_attribute('aria-valuenow','100')
    send({'action':'ui:loading','data':{'phase':'scene'}})
    expect(page.get_by_role('status')).to_contain_text('Ankunft')
    send({'action':'ui:loading','data':{'phase':'session'}})
    expect(page.get_by_role('status')).to_contain_text('Ankunft')  # No phase regression.
    send({'action':'ui:loading','data':{'phase':'exiting'}})
    page.wait_for_timeout(750)
    assert page.locator('.join-screen').evaluate('(el) => getComputedStyle(el).opacity') == '0'
    assert page.locator('body').evaluate('(el) => getComputedStyle(el).backgroundColor') == 'rgba(0, 0, 0, 0)'
    assert page.locator('html').evaluate('(el) => getComputedStyle(el).backgroundColor') == 'rgba(0, 0, 0, 0)'
    # Capture real engine messages while the module entry has not loaded yet.
    def early(route):
        send({'eventName':'loadProgress','loadFraction':.68})
        send({'action':'ui:loading','data':{'phase':'scene'}})
        send({'eventName':'loadProgress','loadFraction':.3})
        route.continue_()
    page.route('**/src/loading/main.tsx', early)
    page.goto('http://127.0.0.1:5173/loading.html',wait_until='networkidle')
    expect(bar).to_have_attribute('aria-valuenow','68')
    expect(page.get_by_role('status')).to_contain_text('Ankunft')
    page.unroute('**/src/loading/main.tsx', early)
    page.emulate_media(reduced_motion='reduce')
    assert page.locator('.join-art').evaluate('(el) => getComputedStyle(el).animationName') == 'none'
    page.keyboard.press('Control+a')
    assert page.evaluate('window.getSelection().toString()') == ''
    page.goto('http://127.0.0.1:5173/?preview=loadscreen',wait_until='networkidle')
    frame = page.frame_locator('iframe')
    expect(frame.locator('.join-screen')).to_be_visible()
    expect(frame.locator('.join-loading-note')).to_contain_text('VORSCHAU')
    page.get_by_role('button',name='UI ausblenden',exact=True).click()
    expect(page.locator('iframe')).to_have_count(0)
    assert not errors, errors
    browser.close()
print('PASS: native/early progress, validation, terminal fade, 6 viewports, reduced motion, Studio')
