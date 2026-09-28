"""Actual React ATM flows and all bank variants, including NUI error recovery."""
from pathlib import Path
from playwright.sync_api import sync_playwright, expect
import json

Path('.codex-log').mkdir(exist_ok=True)
with sync_playwright() as p:
    browser=p.chromium.launch(channel='chrome',headless=True)
    page=browser.new_page(viewport={'width':1920,'height':1080})
    errors=[]
    page.on('pageerror',lambda err:errors.append(str(err)))
    for view,brand in [('banking','fleeca'),('atm-maze','maze'),('atm-liberty','liberty')]:
        page.goto('http://127.0.0.1:5173/?view='+view,wait_until='networkidle')
        expect(page.locator('.atm-'+brand)).to_be_visible()
        page.evaluate("document.body.style.background='url(/src/dev/assets/gta-street.jpg) center / cover no-repeat fixed'")
        for w,h in [(1280,720),(1920,1080),(3840,2160),(3440,1440),(1280,1024),(740,900)]:
            page.set_viewport_size({'width':w,'height':h})
            box=page.locator('.atm-terminal').bounding_box()
            assert box['x']>=0 and box['y']>=0 and box['x']+box['width']<=w+1 and box['y']+box['height']<=h+1,(view,w,box)
            page.screenshot(path=f'.codex-log/atm-{brand}-{w}x{h}.png')
    page.set_viewport_size({'width':1920,'height':1080})
    page.goto('http://127.0.0.1:5173/?view=banking',wait_until='networkidle')
    page.get_by_role('button',name='Einzahlen',exact=False).click()
    page.get_by_role('textbox',name='Betrag',exact=True).fill('500')
    page.get_by_role('button',name='Weiter',exact=False).click()
    expect(page.get_by_role('heading',name='Einzahlen bestätigen')).to_be_visible()
    page.get_by_role('button',name='Bestätigen',exact=True).click()
    expect(page.locator('.atm-done')).to_contain_text('$19.140')
    page.get_by_role('button',name='Weitere Transaktion').click()
    expect(page.locator('.atm-balance')).to_contain_text('$1.950')
    page.get_by_role('button',name='Auszahlen',exact=False).click()
    page.get_by_role('textbox',name='Betrag',exact=True).fill('999999')
    page.get_by_role('button',name='Weiter',exact=False).click()
    expect(page.get_by_role('alert')).to_contain_text('reicht dein Guthaben nicht')
    page.get_by_role('textbox',name='Betrag',exact=True).fill('100')
    page.get_by_role('button',name='Weiter',exact=False).click()
    page.get_by_role('button',name='Bestätigen',exact=True).click()
    expect(page.locator('.atm-done')).to_contain_text('$19.040')
    page.get_by_role('button',name='Weitere Transaktion').click()
    page.get_by_role('button',name='Überweisen',exact=False).click()
    page.get_by_role('textbox',name='Empfänger-ID').fill('42')
    page.get_by_role('button',name='Empfänger prüfen').click()
    expect(page.locator('.atm-recipient')).to_contain_text('Alex Morgan')
    page.get_by_role('textbox',name='Betrag',exact=True).fill('250')
    page.get_by_role('textbox',name='Verwendungszweck').fill('Testzahlung')
    page.get_by_role('button',name='Weiter',exact=False).click()
    expect(page.locator('.atm-confirm')).to_contain_text('Alex Morgan · ID 42')
    page.get_by_role('button',name='Bestätigen',exact=True).click()
    expect(page.locator('.atm-done')).to_contain_text('$18.790')
    page.get_by_role('button',name='Weitere Transaktion').click()
    page.get_by_role('button',name='Kontoverlauf',exact=False).click()
    expect(page.locator('.atm-history li').first).to_contain_text('Alex Morgan')
    expect(page.locator('.atm-history li').first).to_contain_text('−$250')
    page.get_by_role('button',name='Zurück',exact=True).click()
    page.keyboard.press('ArrowDown')
    assert page.evaluate("document.activeElement.tagName==='BUTTON'")
    page.keyboard.press('Escape')
    expect(page.locator('.atm-terminal')).to_have_count(0)

    # Live NUI mode: real typed envelope, retained request on error, double-click guard.
    page.add_init_script("window.GetParentResourceName=()=> 'rp_ui'")
    requests=[]
    def nui(route):
        body=route.request.post_data_json
        requests.append((route.request.url,body))
        if body.get('action')=='transact':
            route.fulfill(status=200,content_type='application/json',body=json.dumps({'ok':False,'error':'review_required'}))
        else:
            route.fulfill(status=200,content_type='application/json',body='{"ok":true}')
    page.route('https://rp_ui/**',nui)
    page.goto('http://127.0.0.1:5173/?view=banking',wait_until='networkidle')
    fixture=page.evaluate("async()=> (await import('/src/lib/banking.ts')).bankPreview('maze')")
    page.evaluate("payload=>window.postMessage({action:'ui:open',data:{view:'banking',locked:false,payload}},'*')",fixture)
    page.get_by_role('button',name='Einzahlen',exact=False).click()
    page.get_by_role('textbox',name='Betrag',exact=True).fill('10')
    page.get_by_role('button',name='Weiter',exact=False).click()
    page.get_by_role('button',name='Bestätigen',exact=True).click()
    expect(page.get_by_role('alert')).to_contain_text('Buchung wird geprüft')
    first=[body for _,body in requests if body.get('action')=='transact'][-1]
    page.get_by_role('button',name='Bestätigen',exact=True).click()
    second=[body for _,body in requests if body.get('action')=='transact'][-1]
    assert first['request']==second['request'] and first['amount']==10 and first['kind']=='deposit'
    page.get_by_role('button',name='Geldautomat schließen').click()
    expect(page.locator('.atm-terminal')).to_have_count(0)
    assert any(url.endswith('/ui:close') for url,_ in requests)
    assert page.evaluate("async()=>{const {parseBanking}=await import('/src/lib/banking.ts');return parseBanking({brand:'wrong'})===null}")
    assert not errors,errors
    browser.close()
print('PASS: ATM variants at 720p/1080p/4K/4:3, deposits/withdrawals/transfers/history, keyboard, NUI errors and close')
