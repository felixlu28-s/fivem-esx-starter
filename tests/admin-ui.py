"""Admin uses the existing NativeMenu renderer, including remapped toggle keys."""
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

Path('.codex-log').mkdir(exist_ok=True)
with sync_playwright() as p:
    browser = p.chromium.launch(channel='chrome', headless=True)
    page = browser.new_page(viewport={'width':1920,'height':1080})
    errors = []
    page.on('pageerror', lambda e: errors.append(str(e)))
    for width,height in [(1280,720),(1920,1080),(3840,2160),(3440,1440),(740,900)]:
        page.set_viewport_size({'width':width,'height':height})
        page.goto('http://127.0.0.1:5173/?view=admin',wait_until='networkidle')
        expect(page.locator('.native-banner')).to_contain_text('Administration')
        box = page.locator('.native-menu').bounding_box()
        assert box['x']>=0 and box['y']>=0 and box['x']+box['width']<=width and box['y']+box['height']<=height
        page.keyboard.press('Enter')
        expect(page.locator('.native-subtitle')).to_contain_text('GELDVERGABE')
        page.keyboard.press('ArrowDown')
        page.keyboard.press('ArrowRight')
        expect(page.locator('.native-row.is-selected')).to_contain_text('Bankkonto')
        page.keyboard.press('F10')
        expect(page.locator('.native-menu')).to_have_count(0)
    page.goto('http://127.0.0.1:5173/?preview=admin',wait_until='networkidle')
    expect(page.frame_locator('iframe').locator('.native-banner')).to_contain_text('Administration')
    # Actual NUI key protocol: the remapped key closes; the old F10 does nothing.
    game=browser.new_page(viewport={'width':1920,'height':1080})
    game.add_init_script('window.GetParentResourceName=()=>"rp_ui"')
    calls=[]
    def route(r):
        if r.request.url.endswith('rp_nativeui:input'):
            calls.append(r.request.post_data_json)
            r.fulfill(json={'ok':True,'closed':True})
        else: r.fulfill(json={'ok':True})
    game.route('https://rp_ui/**',route)
    game.goto('http://127.0.0.1:5173/?view=admin',wait_until='networkidle')
    game.evaluate('''async()=>{const payload=(await import('/src/lib/nativePreview.ts')).nativePreview();
      window.postMessage({action:'ui:open',data:{view:'nativeui',payload,locked:true,toggleKey:'F6'}},'*');}''')
    expect(game.locator('.native-menu')).to_be_visible()
    game.keyboard.press('F10')
    expect(game.locator('.native-menu')).to_be_visible()
    assert not calls
    game.keyboard.press('F6')
    expect(game.locator('.native-menu')).to_have_count(0)
    assert len(calls)==1 and calls[0]['key']=='close' and calls[0]['session']=='preview'
    page.set_viewport_size({'width':1920,'height':1080})
    page.goto('http://127.0.0.1:5173/?view=admin',wait_until='networkidle')
    page.add_style_tag(content='body {background:url("/src/dev/assets/gta-street.jpg") center / cover no-repeat;}')
    page.screenshot(path='.codex-log/admin-menu.png')
    assert not errors,errors
    browser.close()
print('PASS: admin preview, 5 viewports through 4K, money submenu, F10 and remapped NUI toggle')
