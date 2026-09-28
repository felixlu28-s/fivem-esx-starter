"""Real phone renderer, keyboard state, NUI gate, responsive shell and app cache."""
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

Path('.codex-log').mkdir(exist_ok=True)
with sync_playwright() as p:
    browser=p.chromium.launch(channel='chrome',headless=True)
    page=browser.new_page(viewport={'width':1920,'height':1080})
    errors=[]
    page.on('pageerror',lambda e:errors.append(str(e)))
    def press(key):
        page.keyboard.press(key)
        page.wait_for_timeout(140)
    for w,h in [(1280,720),(1920,1080),(2560,1440),(3840,2160),(3440,1440),(740,900)]:
        page.set_viewport_size({'width':w,'height':h})
        page.goto('http://127.0.0.1:5173/?view=phone&phoneDemo=0',wait_until='networkidle')
        phone=page.locator('.phone-device')
        box=phone.bounding_box()
        assert box['x']>=w/2 and box['y']>=0 and box['x']+box['width']<=w and box['y']+box['height']<=h
        expect(page.locator('.phone-app-title')).to_have_text('Contacts')
        press('Enter')
        expect(page.locator('.phone-empty')).to_contain_text('Noch keine Kontakte')
        press('Backspace')
        expect(phone).to_have_attribute('data-page','home')
        press('Backspace')
        expect(phone).to_have_attribute('data-open','false')
        page.wait_for_timeout(650)
        peek=phone.bounding_box()
        assert h-peek['y']>20 and h-peek['y']<h*.14
        expect(page.locator('.phone-status time')).to_be_in_viewport()
        press('ArrowUp')
        expect(phone).to_have_attribute('data-open','true')
    # Enter calendar, change month, go Home via physical navigation, inspect recents.
    page.set_viewport_size({'width':1920,'height':1080})
    page.goto('http://127.0.0.1:5173/?view=phone&phoneDemo=0',wait_until='networkidle')
    press('ArrowRight') # contacts -> calendar
    press('Enter')
    first=page.locator('.phone-month').inner_text()
    press('ArrowRight')
    assert page.locator('.phone-month').inner_text()!=first
    press('ArrowDown') # physical Home
    expect(page.locator('.phone-navigation [aria-label="Home"]')).to_have_attribute('aria-pressed','true')
    press('Enter')
    expect(page.locator('.phone-device')).to_have_attribute('data-page','home')
    press('ArrowDown') # tasks
    press('ArrowDown') # physical recents
    press('Enter')
    expect(page.locator('.phone-device')).to_have_attribute('data-page','recent')
    expect(page.locator('.phone-recent')).to_have_count(1)
    press('Enter')
    assert page.locator('.phone-month').inner_text()!=first # retains app state
    press('ArrowDown'); press('ArrowLeft'); press('Enter') # recents from app
    press('ArrowDown'); press('Enter') # really close calendar
    expect(page.locator('.phone-recent')).to_have_count(0)
    press('Backspace')
    expect(page.locator('.phone-device')).to_have_attribute('data-page','home')
    press('Enter')
    expect(page.locator('.phone-month')).to_have_text(first) # cache closed/reset
    # No text selection and no pointer interaction; browser Studio entry exists.
    page.keyboard.press('Control+a')
    assert page.evaluate('getSelection().toString()')==''
    page.goto('http://127.0.0.1:5173/?preview=phone',wait_until='networkidle')
    expect(page.frame_locator('iframe').locator('.phone-device')).to_have_attribute('data-open','true')
    # Real NUI: no server-granted presence -> hidden, then injected typed state.
    game=browser.new_page(viewport={'width':1920,'height':1080})
    game.add_init_script('window.GetParentResourceName=()=>"rp_ui"')
    calls=[]
    def route(r):
        calls.append((r.request.url.rsplit('/',1)[-1],r.request.post_data_json))
        r.fulfill(json={'ok':True})
    game.route('https://rp_ui/**',route)
    game.goto('http://127.0.0.1:5173/?view=phone&phoneDemo=0',wait_until='networkidle')
    expect(game.locator('.phone-device')).to_have_class(__import__('re').compile('unavailable'))
    game.evaluate('window.postMessage({action:"ui:phone",data:{available:true,open:true,session:"server-session",toggleKey:"F6"}},"*")')
    expect(game.locator('.phone-device')).to_have_attribute('data-open','true')
    game.keyboard.press('ArrowLeft'); game.wait_for_timeout(140)
    assert any(name=='rp_phone:key' and d['key']=='left' and d['session']=='server-session' for name,d in calls)
    n=len(calls)
    game.keyboard.press('w'); game.wait_for_timeout(140)
    assert len(calls)==n # game movement not sent as phone action
    game.keyboard.press('F6'); game.wait_for_timeout(140)
    assert any(name=='rp_phone:close' and d['session']=='server-session' for name,d in calls)
    game.evaluate('window.postMessage({action:"ui:phoneApp",data:{kind:"message"}},"*")')
    expect(game.locator('.phone-brand')).to_have_text('Nachricht')
    expect(game.locator('.phone-new-message')).to_have_count(1)
    game.evaluate('window.postMessage({action:"ui:phoneApp",data:{kind:"reset"}},"*")')
    expect(game.locator('.phone-new-message')).to_have_count(0)
    game.evaluate('window.postMessage({action:"ui:phone",data:false},"*")')
    expect(game.locator('.phone-device')).to_have_attribute('aria-hidden','true')
    page.goto('http://127.0.0.1:5173/?view=phone&phoneDemo=0',wait_until='networkidle')
    page.add_style_tag(content='body {background:url("/src/dev/assets/gta-street.jpg") center / cover no-repeat;}')
    page.screenshot(path='.codex-log/phone-home.png')
    assert not errors,errors
    browser.close()
print('PASS: phone at 6 resolutions through 4K, peek, all navigation modes, recents restore/close, Studio and real NUI protocol')
