"""Real keyboard + NUI errors: drafts, lost focus, cancellation and closing."""
from playwright.sync_api import sync_playwright, expect
from phone_keyboard import PhoneKeyboard

with sync_playwright() as p:
    browser = p.chromium.launch(channel='chrome', headless=True)
    page = browser.new_page(viewport={'width': 1920, 'height': 1080})
    errors = []
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.add_init_script("""
      window.GetParentResourceName = () => 'rp_ui';
      window.requests = []; window.failAction = 'contact'; window.failure = 'unavailable';
      window.hold = false; window.session = 'test-error';
      window.phoneState = open => window.postMessage({action:'ui:phone', data:{
        available:true, open, session:window.session, toggleKey:'UP'
      }}, '*');
      window.fetch = async (url, options) => {
        const route = String(url).split('/').pop(), data = JSON.parse(options.body);
        window.requests.push({route,...data});
        let response = {ok:true};
        if (route === 'rp_phone:close') window.phoneState(false);
        if (route === 'rp_phone:action') {
          if (data.action === window.failAction) {
            if (window.hold) await new Promise(resolve => window.release = resolve);
            else await new Promise(resolve => setTimeout(resolve, 300));
            if (window.failure === 'network') throw new TypeError('Failed to fetch');
            response = {ok:false, error:window.failure};
          } else {
            const {phonePreview} = await import('/src/lib/phonePreview.ts');
            response = await phonePreview(data.action, data.data);
          }
        }
        return new Response(JSON.stringify(response));
      };
    """)
    page.goto('http://127.0.0.1:5173/', wait_until='networkidle')
    page.evaluate('phoneState(true)')
    phone = PhoneKeyboard(page)
    phone.app('Contacts')
    phone.choose('Kontakt hinzufügen')
    page.get_by_label('Name', exact=True).fill('Fehler Test')
    page.get_by_label('Nummer', exact=True).fill('5550000006')
    phone.press('Enter')
    expect(page.locator('.phone-app-error')).to_contain_text('nicht erreichbar')
    expect(page.get_by_label('Nummer', exact=True)).to_be_focused()
    expect(page.get_by_label('Name', exact=True)).to_have_value('Fehler Test')
    phone.press('ArrowUp')
    expect(page.get_by_label('Name', exact=True)).to_be_focused()
    phone.press('Backspace')
    expect(page.get_by_label('Name', exact=True)).to_have_value('Fehler Tes')
    # No click/fill after the rejected request: real keys must work immediately.
    phone.press('Escape')
    expect(page.locator('.phone-form')).to_have_count(0)
    phone.home()
    phone.press('Backspace')
    expect(page.locator('.phone-device')).to_have_attribute('data-open', 'false')
    assert page.evaluate("requests.filter(r=>r.route==='rp_phone:typing').at(-1).active") is False

    # Transport rejection, timeout response and lost DOM focus all leave an exit.
    for failure, back_key in [('network', '\\'), ('timeout', 'Escape')]:
        page.evaluate('(failure)=>{window.failure=failure;phoneState(true)}', failure)
        phone.app('Contacts'); phone.choose('Kontakt hinzufügen')
        page.get_by_label('Name', exact=True).fill('Noch ein Versuch')
        page.get_by_label('Nummer', exact=True).fill('5550000006')
        phone.press('Enter')
        expect(page.locator('.phone-form')).to_have_attribute('aria-busy', 'false')
        expect(page.locator('.phone-app-error')).to_be_visible()
        page.evaluate('document.activeElement.blur()')
        phone.press(back_key)
        expect(page.locator('.phone-form')).to_have_count(0)
        phone.home(); phone.press('Backspace')
        expect(page.locator('.phone-device')).to_have_attribute('data-open', 'false')

    # A request without an answer must not prevent cancelling/putting the phone away.
    page.evaluate("hold=true;failure='unavailable';phoneState(true)")
    phone.app('Contacts'); phone.choose('Kontakt hinzufügen')
    page.get_by_label('Name', exact=True).fill('Warten')
    page.get_by_label('Nummer', exact=True).fill('5550000006')
    phone.press('Enter')
    page.wait_for_function("typeof release==='function'")
    expect(page.locator('.phone-form')).to_have_attribute('aria-busy', 'true')
    expect(page.get_by_role('button', name='Abbrechen', exact=True)).to_be_enabled()
    before = page.evaluate("requests.filter(r=>r.action==='contact').length")
    phone.press('Enter')
    assert page.evaluate("requests.filter(r=>r.action==='contact').length") == before, 'No duplicate submit'
    page.evaluate('document.activeElement.blur()')
    phone.press('ArrowDown')
    expect(page.get_by_label('Name', exact=True)).to_be_focused()
    # Backspace on a button means Back; inside text it only deletes a character.
    phone.press('ArrowDown'); phone.press('ArrowDown')
    expect(page.get_by_role('button', name='Abbrechen', exact=True)).to_be_focused()
    phone.press('Backspace')
    expect(page.locator('.phone-form')).to_have_count(0)
    phone.home(); phone.press('Backspace')
    expect(page.locator('.phone-device')).to_have_attribute('data-open', 'false')
    page.evaluate('hold=false;release()')
    page.wait_for_timeout(400)
    expect(page.locator('.phone-device')).to_have_attribute('data-open', 'false')
    assert page.evaluate("requests.filter(r=>r.route==='rp_phone:typing').at(-1).active") is False

    # Non-form call failures must still navigate back and close normally.
    page.evaluate("failAction='call_start';failure='number_unavailable';phoneState(true)")
    phone.app('Contacts'); phone.choose('Lena Fischer'); phone.choose('Anrufen')
    expect(page.locator('.phone-app-error')).to_contain_text('nicht erreichbar')
    phone.home(); phone.press('Backspace')
    expect(page.locator('.phone-device')).to_have_attribute('data-open', 'false')

    # Tasks/iFruit now share the same resilient form keyboard handler.
    page.evaluate("failAction='task';failure='unavailable';phoneState(true)")
    phone.app('Tasks'); phone.press('Enter')
    expect(page.locator('.phone-form')).to_have_count(1)
    page.get_by_label('Was möchtest du erledigen?', exact=True).fill('Bleibt erhalten')
    phone.press('Enter')
    expect(page.locator('.phone-app-error')).to_contain_text('nicht verfügbar')
    expect(page.get_by_label('Was möchtest du erledigen?', exact=True)).to_have_value('Bleibt erhalten')
    page.evaluate('document.activeElement.blur()')
    phone.press('\\')
    phone.home(); phone.press('Backspace')
    expect(page.locator('.phone-device')).to_have_attribute('data-open', 'false')

    # A Lua-side close (item loss/command/death) also relinquishes form focus.
    page.evaluate('phoneState(true)')
    phone.app('Tasks'); phone.press('Enter')
    expect(page.locator('.phone-form')).to_have_count(1)
    page.evaluate('phoneState(false)')
    page.wait_for_function("requests.filter(r=>r.route==='rp_phone:typing').at(-1).active===false")
    phone.press('Escape')
    expect(page.locator('.phone-device')).to_have_attribute('data-open', 'false')
    assert not errors, errors
    browser.close()
print('PASS: phone server/network/timeout errors, draft/focus recovery, pending cancellation, duplicate guard, late replies, call/tasks errors and close/input release')
