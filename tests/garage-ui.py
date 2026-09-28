"""Garage surfaces reuse the actual keyboard-driven NativeUI renderer."""
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

Path('.codex-log').mkdir(exist_ok=True)
with sync_playwright() as p:
    browser=p.chromium.launch(channel='chrome',headless=True)
    page=browser.new_page(viewport={'width':1920,'height':1080});errors=[]
    page.on('pageerror',lambda e:errors.append(str(e)))
    for width,height in [(1280,720),(1920,1080),(3840,2160),(3440,1440),(740,900)]:
        page.set_viewport_size({'width':width,'height':height})
        page.goto('http://127.0.0.1:5173/?view=garage-dev',wait_until='networkidle')
        page.keyboard.press('ArrowDown');page.keyboard.press('Enter')
        expect(page.locator('.native-menu')).to_have_class('native-menu native-theme-mint')
        expect(page.locator('.native-subtitle')).to_contain_text('LA MESA')
        for _ in range(3):page.keyboard.press('ArrowDown')
        page.keyboard.press('Enter')
        expect(page.locator('.native-rows')).to_contain_text('prop_id2_11_gdoor')
        for _ in range(3):page.keyboard.press('ArrowDown')
        expect(page.locator('.native-row.is-selected')).to_have_attribute('aria-checked','false')
        page.keyboard.press('Enter')
        expect(page.locator('.native-row.is-selected')).to_have_attribute('aria-checked','true')
        box=page.locator('.native-menu').bounding_box()
        assert box['x']>=0 and box['x']+box['width']<=width and box['y']+box['height']<=height
        page.keyboard.press('Backspace')
        expect(page.locator('.native-row.is-selected')).to_contain_text('Tor auswählen')
        if width==1920:page.screenshot(path='.codex-log/garage-dev.png')
    page.goto('http://127.0.0.1:5173/?view=garage',wait_until='networkidle')
    expect(page.locator('.native-rows')).to_contain_text('RP520367')
    page.goto('http://127.0.0.1:5173/',wait_until='networkidle')
    expect(page.get_by_role('button',name='Garagenverwaltung',exact=False)).to_be_visible()
    assert not errors,errors
    browser.close()
print('garage-ui: menu/submenus, mint theme, keyboard checkbox, Studio and five resolutions passed')
