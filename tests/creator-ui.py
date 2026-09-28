"""Creator, 4K scaling and actual NUI camera requests. Vite + Playwright/Chrome."""
import json
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

url = 'http://127.0.0.1:5173/?view=creator'
out = Path('.codex-log')
out.mkdir(exist_ok=True)
errors = []
with sync_playwright() as p:
    browser = p.chromium.launch(channel='chrome', headless=True)
    page = browser.new_page(viewport={'width':1920,'height':1080})
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.goto(url, wait_until='networkidle')
    expect(page.locator('.scene-shade')).to_have_count(0)
    expect(page.locator('.creator-tabs button svg')).to_have_count(7)
    expect(page.locator('.camera-presets button svg')).to_have_count(5)
    assert all(not text.strip() for text in page.locator('.camera-presets button').all_text_contents()), 'camera presets are icons, labels remain accessible'
    page.get_by_role('button', name='Editor ausblenden').click()
    expect(page.locator('.creator-panel')).to_be_hidden()
    expect(page.locator('.camera-drag-area')).to_be_visible()
    page.get_by_role('button', name='Editor einblenden').click()
    expect(page.locator('.creator-panel')).to_be_visible()
    page.get_by_label('Vorname', exact=True).fill('Alex')
    page.get_by_role('button', name='Weiblich', exact=True).click()
    page.get_by_role('button', name='04 Haare').click()
    expect(page.get_by_label('Frisur', exact=True)).to_have_attribute('max', '82')
    expect(page.locator('summary').filter(has_text='Bart')).to_have_count(0)
    page.get_by_role('button', name='06 Kleidung').click()
    for label, section in [('Oberteil', 'Oberteile'), ('Hose', 'Hosen & Unterteile'), ('Schuhe', 'Schuhe')]:
        detail = page.locator('details').filter(has=page.locator('summary').filter(has_text=section))
        if detail.get_attribute('open') is None:
            detail.locator('summary').click()
        expect(page.get_by_label(label, exact=True).locator('option')).to_have_count(12)
    page.get_by_label('Oberteil', exact=True).select_option('4')
    page.get_by_role('button', name='01 Identität').click()
    expect(page.get_by_label('Vorname', exact=True)).to_have_value('Alex')
    page.get_by_role('button', name='Männlich', exact=True).click()
    page.get_by_role('button', name='04 Haare').click()
    expect(page.get_by_label('Frisur', exact=True)).to_have_attribute('max', '78')
    expect(page.locator('summary').filter(has_text='Bart')).to_have_count(1)
    page.get_by_label('Einstellungen durchsuchen').fill('Bart')
    expect(page.get_by_label('Bart · Stärke', exact=True)).to_be_visible()

    # Font/control sizes track resolution; no horizontal document overflow.
    dimensions = {}
    for width,height in [(1280,720),(1366,768),(1920,1080),(2560,1440),(3840,2160),(3440,1440),(740,900)]:
        page.set_viewport_size({'width':width,'height':height})
        page.goto(url, wait_until='networkidle')
        panel = page.locator('.creator-panel').bounding_box()
        footer = page.get_by_role('button', name='Weiter').bounding_box()
        assert panel['x'] >= 0 and panel['x'] + panel['width'] <= width
        if width >= 1920:
            assert panel['width'] / width < .24, 'editor must leave the character most of the screen'
        camera = page.locator('.camera-controls').bounding_box()
        assert camera['x'] >= 0 and camera['x'] + camera['width'] <= width
        assert footer['y'] + footer['height'] <= height
        assert page.locator('body').evaluate('(e)=>e.scrollWidth <= innerWidth')
        dimensions[width] = (panel['width'], page.get_by_label('Vorname', exact=True).evaluate('(e)=>parseFloat(getComputedStyle(e).fontSize)'))
        page.screenshot(path=str(out / f'creator-new-{width}.png'))
    assert 1.98 < dimensions[3840][0] / dimensions[1920][0] < 2.02
    assert 1.98 < dimensions[3840][1] / dimensions[1920][1] < 2.02
    for view in ['me','settings']:
        sizes = []
        for width,height in [(1920,1080),(3840,2160)]:
            page.set_viewport_size({'width':width,'height':height})
            page.goto(f'http://127.0.0.1:5173/?view={view}', wait_until='networkidle')
            box = page.locator('.menu-shell').bounding_box()
            assert box['x'] >= 0 and box['x'] + box['width'] <= width
            assert box['y'] >= 0 and box['y'] + box['height'] <= height
            sizes.append(page.locator('.menu-header h1').evaluate('(e)=>parseFloat(getComputedStyle(e).fontSize)'))
            page.screenshot(path=str(out / f'{view}-scaled-{width}.png'))
        assert 1.98 < sizes[1] / sizes[0] < 2.02

    # Use the real fetch bridge on a separate mocked FiveM page to capture calls.
    game = browser.new_page(viewport={'width':1920,'height':1080})
    game.on('pageerror', lambda e: errors.append(str(e)))
    game.add_init_script('window.GetParentResourceName=()=>"rp_ui"')
    calls = []
    def route(request):
        if request.request.url.endswith('rp_characters:camera'):
            calls.append(request.request.post_data_json)
        request.fulfill(json={'ok':True})
    game.route('https://rp_ui/**', route)
    game.goto(url, wait_until='networkidle')
    fixture = json.loads(Path('server-data/resources/[custom]/rp_ui/web/src/lib/appearance-preview.json').read_text(encoding='utf-8'))[0]
    payload = {**fixture, 'mode':'creator','characters':[],'slots':1,'minAge':18,'maxAge':100}
    game.evaluate('(payload)=>window.postMessage({action:"ui:open",data:{view:"characters",payload,locked:true}},"*")', payload)
    game.locator('.camera-drag-area').wait_for()
    expect(game.locator('.scene-shade')).to_have_count(0)
    assert game.locator('.character-shell').evaluate('(e)=>getComputedStyle(e).backgroundColor') == 'rgba(0, 0, 0, 0)', 'no tinted creator overlay in FiveM'
    for label, view in [('Gesicht','face'),('Oberkörper','upper'),('Unterkörper','lower'),('Schuhe','shoes'),('Ganzkörper','body')]:
        game.locator('.camera-presets').get_by_role('button', name=label, exact=True).click()
        game.wait_for_timeout(80)
        assert calls[-1]['view'] == view
    area = game.locator('.camera-drag-area').bounding_box()
    x, y = area['x'] + area['width']/2, area['y'] + area['height']/2
    game.mouse.move(x,y)
    game.mouse.down()
    game.mouse.move(x+250,y+150,steps=12)
    game.mouse.up()
    game.wait_for_timeout(100)
    assert calls[-1]['rotation'] > 0 and calls[-1]['pitch'] > 0
    for _ in range(12):
        game.mouse.wheel(0,-800)
    game.wait_for_timeout(150)
    assert calls[-1]['zoom'] == 0
    for _ in range(12):
        game.mouse.wheel(0,800)
    game.wait_for_timeout(150)
    assert calls[-1]['zoom'] == 1
    previous = len(calls)
    game.get_by_label('Vorname', exact=True).hover()
    game.mouse.wheel(0,500)
    game.wait_for_timeout(100)
    assert len(calls) == previous, 'scrolling the form must not zoom the camera'
    game.get_by_role('button',name='Zentrieren').click()
    game.wait_for_timeout(100)
    assert calls[-1]['rotation'] == 0 and calls[-1]['pitch'] == 0
    browser.close()
assert not errors, errors
print('PASS: male/female catalogs, arrival choices, seven viewports, 4K scale, five camera presets, drag, zoom bounds and form isolation')
