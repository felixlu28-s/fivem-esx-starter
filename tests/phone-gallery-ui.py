"""Real IndexedDB, WebCrypto and MediaRecorder: persistence, tamper checks and UI."""
from pathlib import Path
from playwright.sync_api import sync_playwright, expect
from phone_local_keyboard import LocalPhoneKeyboard

Path('.codex-log').mkdir(exist_ok=True)
with sync_playwright() as p:
    browser=p.chromium.launch(channel='chrome',headless=True)
    context=browser.new_context(viewport={'width':1920,'height':1080})
    page=context.new_page(); errors=[]
    page.on('pageerror',lambda e:errors.append(str(e)))
    page.add_init_script('''window.recorders=[];const Original=MediaRecorder;window.MediaRecorder=class extends Original{constructor(...args){super(...args);recorders.push(this);}}''')
    page.goto('http://127.0.0.1:5173/?view=phone',wait_until='networkidle')
    keys=LocalPhoneKeyboard(page);keys.app('Camera')
    expect(page.get_by_role('button',name='Foto aufnehmen',exact=True)).not_to_have_attribute('aria-disabled','true')
    for width,height in [(1280,720),(1920,1080),(3840,2160),(3440,1440),(740,900)]:
        page.set_viewport_size({'width':width,'height':height});page.wait_for_timeout(100)
        bounds=page.locator('.phone-app-content').bounding_box()
        for button in page.locator('.phone-camera-app [role=button]').all():
            box=button.bounding_box()
            assert box['y']>=bounds['y']-1 and box['y']+box['height']<=bounds['y']+bounds['height']+1
    page.set_viewport_size({'width':1920,'height':1080})
    keys.choose('2× Zoom');keys.choose('Kamera wechseln');keys.choose('Foto aufnehmen')
    expect(page.locator('.camera-library img')).to_be_visible()
    page.locator('.phone-device').screenshot(path='.codex-log/phone-camera.png')
    keys.choose('Video');keys.choose('Video aufnehmen');page.wait_for_timeout(1300)
    assert page.evaluate('recorders.length===1&&recorders[0].stream.getAudioTracks().length===0')
    keys.choose('Kamera wechseln')
    assert page.evaluate('recorders[0].state')=='recording'
    keys.choose('Aufnahme stoppen');page.wait_for_timeout(800)
    assert page.evaluate('recorders[0].state')=='inactive'
    keys.choose('Galerie öffnen');expect(page.locator('.gallery-tile')).to_have_count(2)
    assert page.evaluate('recorders[0].stream.getTracks().every(t=>t.readyState==="ended")')
    video_label=page.locator('.gallery-tile').first.get_attribute('aria-label');keys.choose(video_label)
    keys.choose('Abspielen');page.wait_for_timeout(450)
    assert page.locator('.gallery-viewer video').evaluate('(v)=>v.videoWidth===720&&v.videoHeight===960&&v.currentTime>0')
    keys.choose('Pausieren');keys.press('Backspace')
    # Reload preserves media. A second tab sees the same saved records.
    page.reload(wait_until='networkidle');keys.app('Galerie')
    expect(page.locator('.gallery-tile')).to_have_count(2)
    other=context.new_page();other.goto('http://127.0.0.1:5173/?view=phone',wait_until='networkidle')
    other_keys=LocalPhoneKeyboard(other);other_keys.app('Galerie');expect(other.locator('.gallery-tile')).to_have_count(2);other.close()
    # Wrong character cannot read an authenticated entry, no save/import API exposed.
    probe=page.evaluate('''async()=>{const g=await import('/src/lib/phoneGallery.ts');const {items}=await g.listLocalMedia('browser-preview:1');let denied=false;try{await g.loadLocalMedia('other-character',items[0].id)}catch{denied=true}return {denied,ids:items.map(i=>i.id),noImport:!g.save&&!g.importFile};}''')
    assert probe['denied'] and probe['noImport']
    # Explicit publication has a separate server copy; private source stays local.
    photo_label=page.locator('.gallery-tile').nth(1).get_attribute('aria-label');keys.choose(photo_label)
    expect(page.locator('.gallery-viewer img')).to_be_visible()
    keys.choose('Auf iFruit veröffentlichen');keys.fill({'Bildunterschrift':'Nur dieser Beitrag ist öffentlich.'})
    expect(page.locator('.phone-app-title')).to_have_text('iFruit')
    keys.app('Galerie');expect(page.locator('.gallery-tile')).to_have_count(2)
    page.locator('.phone-device').screenshot(path='.codex-log/phone-gallery.png')
    # Change a thumbnail/canonical date directly in IndexedDB: entry must disappear.
    page.evaluate('''async(id)=>{const db=await new Promise((resolve,reject)=>{const r=indexedDB.open('rp-phone-gallery-v1',1);r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error)});await new Promise((resolve,reject)=>{const tx=db.transaction('entries','readwrite');tx.oncomplete=resolve;tx.onerror=()=>reject(tx.error);const s=tx.objectStore('entries'),r=s.get(id);r.onsuccess=()=>s.put({...r.result,created:r.result.created+1})});db.close()}''',probe['ids'][1])
    page.reload(wait_until='networkidle');keys.app('Galerie')
    expect(page.locator('.gallery-tile')).to_have_count(1)
    expect(page.locator('.gallery-error')).to_contain_text('veränderte Aufnahme')
    # The large media payload is authenticated independently before playback.
    page.evaluate('''async(id)=>{const db=await new Promise(resolve=>{const r=indexedDB.open('rp-phone-gallery-v1',1);r.onsuccess=()=>resolve(r.result)});await new Promise(resolve=>{const tx=db.transaction('media','readwrite');tx.oncomplete=resolve;const s=tx.objectStore('media'),r=s.get(id);r.onsuccess=()=>{const v=r.result;new Uint8Array(v.data)[0]^=1;s.put(v)}});db.close()}''',probe['ids'][0])
    keys.choose(page.locator('.gallery-tile').first.get_attribute('aria-label'))
    expect(page.locator('.gallery-error')).to_contain_text('beschädigt')
    expect(page.locator('.gallery-viewer video')).to_have_count(0)
    keys.choose('Aufnahme löschen');keys.press('ArrowDown');keys.press('Enter');page.wait_for_timeout(500)
    expect(page.locator('.gallery-tile')).to_have_count(0)
    counts=page.evaluate('''async(id)=>{const db=await new Promise(resolve=>{const r=indexedDB.open('rp-phone-gallery-v1',1);r.onsuccess=()=>resolve(r.result)});const results=await Promise.all(['entries','media'].map(name=>new Promise(resolve=>{const r=db.transaction(name).objectStore(name).get(id);r.onsuccess=()=>resolve(!r.result)})));db.close();return results}''',probe['ids'][0])
    assert counts==[True,True],counts
    assert not errors,errors
    browser.close()
print('phone-gallery-ui: photo/video/zoom/lens, 5 resolutions, real WebM playback, reload/tab persistence, character isolation, tamper rejection, explicit publication and deletion passed')
