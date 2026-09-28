"""Real NUI transport: capture remains private, only explicit publication uploads."""
from playwright.sync_api import sync_playwright, expect
from phone_local_keyboard import LocalPhoneKeyboard

with sync_playwright() as p:
    browser=p.chromium.launch(channel='chrome',headless=True)
    page=browser.new_page(viewport={'width':1920,'height':1080})
    errors=[]; requests=[]; attempts=[0]; publications=[]
    page.on('pageerror',lambda e:errors.append(str(e)))
    page.add_init_script('''
        window.GetParentResourceName=()=>"rp_ui";
        window.recorders=[];const Original=MediaRecorder;
        window.MediaRecorder=class extends Original{constructor(...a){super(...a);recorders.push(this)}};
        navigator.mediaDevices.getUserMedia=()=>{throw Error('No real camera/microphone permission allowed')};
    ''')
    def route(r):
        action=r.request.url.rsplit('/',1)[-1];data=r.request.post_data_json
        requests.append((action,data));result={'ok':True}
        if action=='rp_phone:camera' and data.get('mode')!='off':
            attempts[0]+=1
            if attempts[0]<=2:result={'ok':False,'error':'invalid_state'}
        if action=='rp_phone:action':
            if data['action']=='home':
                result['phone']={'kind':'home','profile':{'id':1,'number':'5550000001','name':'Test Joost','handle':'test_joost','bio':'','contacts':[],'tasks':[],'bookmarks':[],
                    'galleryScope':'transport:'+data['session']},'sites':[]}
            elif data['action']=='publish_local':
                publications.append(data['data'])
            elif data['action']=='feed':result['phone']={'kind':'feed','rows':[],'more':False}
            else:raise AssertionError(('Unexpected server gallery action',data))
        r.fulfill(json=result)
    page.route('https://rp_ui/**',route)
    page.goto('http://127.0.0.1:5173/?view=phone',wait_until='networkidle')
    def phone(session='char1',available=True,opened=True):
        page.evaluate('(data)=>window.postMessage({action:"ui:phone",data},"*")',{'available':available,'open':opened,'session':session,'toggleKey':'UP'})
        page.wait_for_timeout(400)
    phone();keys=LocalPhoneKeyboard(page);keys.app('Camera')
    expect(page.get_by_role('button',name='Foto aufnehmen',exact=True)).not_to_have_attribute('aria-disabled','true')
    assert attempts[0]>=3,'Retry until held prop is ready'
    keys.choose('Foto aufnehmen');keys.choose('Video');keys.choose('Video aufnehmen')
    page.wait_for_timeout(800)
    # Forced item loss/death closes native camera and finalizes only local video.
    phone(available=False,opened=False)
    page.wait_for_function('recorders.length===1&&recorders[0].state==="inactive"&&recorders[0].stream.getTracks().every(t=>t.readyState==="ended")')
    page.wait_for_timeout(600)
    assert not publications
    assert all(a!='rp_phone:action' or d['action']=='home' for a,d in requests)
    assert not any('data:image' in str(d) or 'base64' in str(d) for a,d in requests)
    assert [d for a,d in requests if a=='rp_phone:camera'][-1]['mode']=='off'
    phone();keys.app('Galerie');expect(page.locator('.gallery-tile')).to_have_count(2)
    # Server-verified namespace changes with the active ESX character.
    phone('char2');expect(page.locator('.gallery-tile')).to_have_count(0)
    phone();expect(page.locator('.gallery-tile')).to_have_count(2)
    keys.choose(page.locator('.gallery-tile').nth(1).get_attribute('aria-label'))
    keys.choose('Auf iFruit veröffentlichen')
    assert not publications,'Opening confirmation must not upload'
    keys.fill({'Bildunterschrift':'Nur ausdrücklich veröffentlichen.'})
    assert len(publications)==1 and publications[0]['image'].startswith('data:image/jpeg;base64,')
    assert len(publications[0]['image'])<=120000
    keys.app('Galerie');expect(page.locator('.gallery-tile')).to_have_count(2)
    # Reopen private media after full NUI reload without receiving any media bytes.
    page.reload(wait_until='networkidle');phone();keys.app('Galerie')
    expect(page.locator('.gallery-tile')).to_have_count(2)
    assert len(publications)==1 and not errors,errors
    browser.close()
print('phone-gallery-transport: no private upload, delayed prop readiness, capture cleanup, character switch, explicit public copy and local reload passed')
