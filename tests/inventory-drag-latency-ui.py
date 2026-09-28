"""Real NUI bridge with held replies: released tiles never flash at the old slot."""
from copy import deepcopy
from playwright.sync_api import sync_playwright, expect

with sync_playwright() as p:
    browser = p.chromium.launch(channel='chrome', headless=True)
    page = browser.new_page(viewport={'width':1920,'height':1080})
    page.add_init_script('window.GetParentResourceName=()=>"rp_ui"')
    pending, errors = [], []
    page.on('pageerror',lambda e: errors.append(str(e)))
    page.route('https://rp_ui/**',lambda route: pending.append(route) if route.request.url.endswith('rp_inventory:action') else route.fulfill(json={'ok':True}))
    page.goto('http://127.0.0.1:5173/',wait_until='networkidle')
    fixture=page.evaluate("async()=> (await import('/src/lib/inventoryPreview.ts')).inventoryPreview()")
    def publish(data):
        page.evaluate('(payload)=>window.postMessage({action:"ui:open",data:{view:"inventory",payload,locked:false}},"*")',data)
        page.wait_for_timeout(35)
    def slot(side,n): return page.locator(f'.inventory-slot[data-side="{side}"][data-slot="{n}"]')
    def hidden_source(side,n):
        assert slot(side,n).locator('svg').evaluate('(e)=>getComputedStyle(e).visibility')=='hidden'
    def projected(action):
        return page.evaluate('async ([data,action])=>(await import("/src/lib/inventoryPreview.ts")).previewInventoryAction(data,action).inventory',[fixture,action])
    publish(fixture)
    # Successful delayed move, including the normal push-before-callback sequence.
    slot('own',1).drag_to(slot('own',5))
    page.wait_for_timeout(500)
    ghost=page.locator('.inventory-drag-ghost')
    expect(ghost).to_be_visible()
    hidden_source('own',1)
    box,target=ghost.bounding_box(),slot('own',5).bounding_box()
    assert abs(box['x']-target['x'])<1 and abs(box['y']-target['y'])<1
    assert len(pending)==1
    publish(fixture) # Same-revision background refresh must not expose the old item.
    hidden_source('own',1)
    expect(ghost).to_be_visible()
    moved=projected(pending[0].request.post_data_json)
    publish(moved)
    expect(ghost).to_be_visible()
    pending.pop(0).fulfill(json={'ok':True,'inventory':moved})
    expect(ghost).to_have_count(0)
    expect(slot('own',1).locator('svg')).to_have_count(0)
    expect(slot('own',5)).to_contain_text('Mineralwasser')
    # A refusal restores the authoritative original; no stranded drag visual.
    fixture['session']='rejected'
    publish(fixture)
    slot('own',1).drag_to(slot('external',4))
    page.wait_for_timeout(250)
    hidden_source('own',1)
    pending.pop(0).fulfill(json={'ok':False,'error':'too_heavy','inventory':fixture})
    expect(ghost).to_have_count(0)
    expect(slot('own',1).locator('svg')).to_be_visible()
    expect(page.get_by_role('status')).to_contain_text('Tragkraft')
    # Splits, merges and swaps all keep the released tile until confirmation.
    for case in ['split','merge','swap']:
        fixture['session']=case
        publish(fixture)
        target_side,target_slot=('external',1) if case=='merge' else ('own',2 if case=='swap' else 5)
        if case=='split':
            slot('own',1).click(button='right')
            page.get_by_label('Menge',exact=True).fill('2')
            page.get_by_role('button',name='Menge fürs Ziehen übernehmen').click()
        slot('own',1).drag_to(slot(target_side,target_slot))
        page.wait_for_timeout(200)
        hidden_source('own',1)
        expect(ghost).to_be_visible()
        reply=projected(pending[0].request.post_data_json)
        pending.pop(0).fulfill(json={'ok':True,'inventory':reply})
        expect(ghost).to_have_count(0)
        expect(slot(target_side,target_slot)).to_contain_text('Mineralwasser')
        if case=='split': expect(slot('own',1).locator('.inventory-slot-count')).to_contain_text('2')
        if case=='swap': expect(slot('own',1)).to_contain_text('Sandwich')
    # Transport failure cleans the tile; the UI shows an error, never a fake success.
    fixture['session']='network-failure'
    publish(fixture)
    slot('own',1).drag_to(slot('own',5))
    page.wait_for_timeout(100)
    pending.pop(0).abort()
    expect(ghost).to_have_count(0)
    expect(slot('own',1).locator('svg')).to_be_visible()
    expect(page.get_by_role('status')).to_contain_text('Antwort ausgeblieben')
    # New inventory sessions unmount old pending visuals and ignore their late replies.
    fixture['session']='old-view'
    publish(fixture)
    slot('own',1).drag_to(slot('own',5))
    page.wait_for_timeout(100)
    old=projected(pending[0].request.post_data_json)
    replacement=deepcopy(fixture)
    replacement['session']='new-view'
    publish(replacement)
    expect(ghost).to_have_count(0)
    pending.pop(0).fulfill(json={'ok':True,'inventory':old})
    page.wait_for_timeout(100)
    expect(slot('own',1).locator('svg')).to_be_visible()
    expect(slot('own',5).locator('svg')).to_have_count(0)
    assert not errors,errors
    browser.close()
print('PASS: delayed move/push, split, merge, swap, refusal, transport error and late-session reply')
