"""Phone app CRUD and keyboard forms using the same renderer/browser adapter."""
from pathlib import Path
from playwright.sync_api import sync_playwright, expect
from lupa.lua54 import LuaRuntime
from phone_keyboard import PhoneKeyboard
from phone_local_keyboard import LocalPhoneKeyboard

with sync_playwright() as p:
    browser=p.chromium.launch(channel='chrome',headless=True)
    page=browser.new_page(viewport={'width':1920,'height':1080})
    errors=[]
    page.on('pageerror',lambda e:errors.append(str(e)))
    page.goto('http://127.0.0.1:5173/?view=phone&phoneDemo=0',wait_until='networkidle')
    communication=PhoneKeyboard(page)
    local=LocalPhoneKeyboard(page)
    def press(key):
        page.keyboard.press(key);page.wait_for_timeout(160)
    def choose(label):
        if page.locator('.phone-camera-app,.phone-gallery-app').count():return local.choose(label)
        if page.locator('.phone-communication').count():return communication.choose(label)
        # Match row title exactly, excluding detail text.
        indices=page.locator('.phone-action>span').all_text_contents()
        assert label in indices, (label,indices)
        target=indices.index(label)
        current=page.locator('.phone-action').evaluate_all('(rows)=>rows.findIndex(r=>r.getAttribute("aria-selected")==="true")')
        if current<0:press('ArrowUp');current=page.locator('.phone-action').evaluate_all('(rows)=>rows.findIndex(r=>r.getAttribute("aria-selected")==="true")')
        for _ in range(abs(target-current)):press('ArrowDown' if target>current else 'ArrowUp')
        expect(page.locator('.phone-action').nth(target)).not_to_have_attribute('aria-disabled','true')
        press('Enter');page.wait_for_timeout(500)
    def home():
        for _ in range(6):
            if page.locator('.phone-device').get_attribute('data-page')=='home':return
            press('Backspace')
        raise AssertionError('Could not return home')
    def app(label):
        home()
        labels=page.locator('.phone-app>span:last-child').all_text_contents()
        target=labels.index(label)
        current=page.locator('.phone-app').evaluate_all('(rows)=>rows.findIndex(r=>r.getAttribute("aria-selected")==="true")')
        for _ in range(abs(target-current)):press('ArrowRight' if target>current else 'ArrowLeft')
        press('Enter');page.wait_for_timeout(650)
    def fill(values):
        for name,value in values.items():page.get_by_label(name,exact=True).fill(value)
        page.locator('.phone-form button[type=submit]').focus();press('Enter');page.wait_for_timeout(650)
        expect(page.locator('.phone-form')).to_have_count(0)
    expect(page.locator('.phone-app>span:last-child').first).to_have_text('Anrufe')
    press('Enter');page.wait_for_timeout(700)
    choose('Kontakt hinzufügen');fill({'Name':'Alice','Nummer':'5550000002'})
    choose('Kontakt bearbeiten');fill({'Name':'Alice Cooper','Nummer':'5550000002'})
    choose('Nachricht schreiben');choose('Nachricht schreiben');fill({'Nachricht':'Hallo Alice! Grüße aus Los Santos.'})
    expect(page.locator('.phone-app-title')).to_have_text('Messages')
    expect(page.locator('.comm-chat')).to_contain_text('Hallo Alice!')
    app('Tasks');choose('Neue Aufgabe');fill({'Was möchtest du erledigen?':'Auto abholen'})
    choose('○ Auto abholen');choose('Erledigt')
    expect(page.locator('.phone-actions')).to_contain_text('✓ Auto abholen')
    app('Galerie');expect(page.locator('.gallery-empty')).to_be_visible()
    app('Camera');choose('Kamera wechseln');page.wait_for_timeout(700)
    choose('Foto aufnehmen');choose('Galerie öffnen')
    choose(page.locator('.gallery-tile').first.get_attribute('aria-label'))
    expect(page.locator('.gallery-viewer img')).to_be_visible()
    choose('Auf iFruit veröffentlichen');fill({'Bildunterschrift':'Mein erster Tag in Los Santos.'})
    choose('@test_joost');expect(page.locator('.phone-post')).to_contain_text('Mein erster Tag')
    validator=LuaRuntime(unpack_returned_tuples=True)
    validator.execute("PhoneService={} PhoneConfig={photoBytes=120000} dofile('server-data/resources/[custom]/rp_phone/server/media.lua')")
    assert validator.globals().PhoneService.validPhoto(page.locator('.phone-post img').get_attribute('src')), 'Real published JPEG accepted by server validator'
    choose('Gefällt mir');expect(page.locator('.phone-post')).to_contain_text('1 Likes')
    choose('Kommentare');choose('Kommentieren');fill({'Dein Kommentar':'Schöne Stadt!'})
    expect(page.locator('.phone-comments')).to_contain_text('Schöne Stadt!')
    home();app('Anrufe');choose('Nummer eingeben');fill({'Telefonnummer':'5550000002'});choose('Videoanruf starten')
    expect(page.locator('.phone-call-members')).to_contain_text('Alice Cooper')
    choose('Teilnehmer hinzufügen');fill({'Telefonnummer':'5550000003'})
    expect(page.locator('.phone-call-title')).to_contain_text('Konferenz')
    choose('Mikrofon stummschalten');expect(page.locator('.phone-call-members')).to_contain_text('Mikro aus')
    choose('Auflegen');expect(page.locator('.phone-call-members')).to_have_count(0)
    home();app('iFruit');choose('@test_joost')
    Path('.codex-log').mkdir(exist_ok=True)
    page.screenshot(path='.codex-log/phone-social.png')
    assert not errors,errors
    browser.close()
print('phone-apps-ui: contacts, messages, keyboard forms, tasks, local camera/gallery, social and conference controls passed')
