"""Attachment tooltip/removal/reinstallation through the real inventory renderer."""
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

with sync_playwright() as p:
    browser = p.chromium.launch(channel='chrome', headless=True)
    page = browser.new_page(viewport={'width': 1920, 'height': 1080})
    errors = []
    page.on('pageerror', lambda e: errors.append(str(e)))
    url = 'http://127.0.0.1:5173/?view=inventory'
    def slot(side, number):
        return page.locator(f'.inventory-slot[data-side="{side}"][data-slot="{number}"]')
    page.goto(url, wait_until='networkidle')
    slot('own', 7).hover()
    tip = page.get_by_role('tooltip')
    expect(tip).to_contain_text('Pistolenlampe')
    expect(tip).to_contain_text('Pistolen-Schalldämpfer')
    slot('own', 7).click(button='right')
    expect(tip).to_have_count(0)
    page.get_by_role('button', name='Aufsatz entfernen', exact=True).click()
    page.get_by_role('button', name='Pistolen-Schalldämpfer', exact=True).click()
    expect(slot('own', 4)).to_contain_text('Pistolen-Schalldämpfer')
    slot('own', 7).hover()
    expect(tip).to_contain_text('Pistolenlampe')
    expect(tip).not_to_contain_text('Schalldämpfer')
    slot('own', 4).click(button='right')
    page.get_by_role('button', name='Benutzen', exact=True).click()
    expect(slot('own', 4)).not_to_contain_text('Schalldämpfer')
    slot('own', 7).hover()
    expect(tip).to_contain_text('Pistolen-Schalldämpfer')
    slot('own', 7).drag_to(slot('external', 3))
    slot('external', 3).hover()
    expect(tip).to_contain_text('Pistolen-Schalldämpfer')
    slot('external', 3).click(button='right')
    expect(page.get_by_role('button', name='Aufsatz entfernen', exact=True)).to_have_count(0)
    page.keyboard.press('Escape')
    slot('external', 3).drag_to(slot('own', 7))
    slot('own', 7).hover()
    expect(tip).to_contain_text('Pistolenlampe')
    for width, height in [(1280,720),(1920,1080),(3840,2160),(3440,1440),(740,760)]:
        page.set_viewport_size({'width':width,'height':height})
        page.mouse.move(1,1)
        slot('own', 7).hover()
        expect(tip).to_be_visible()
        box=tip.bounding_box()
        assert box['x']>=0 and box['y']>=0 and box['x']+box['width']<=width and box['y']+box['height']<=height
        slot('own', 7).click(button='right')
        page.get_by_role('button',name='Aufsatz entfernen',exact=True).click()
        menu=page.get_by_role('dialog',name='Gegenstandsaktionen')
        expect(menu.get_by_role('button',name='Pistolenlampe',exact=True)).to_be_visible()
        box=menu.bounding_box()
        assert box['x']>=0 and box['y']>=0 and box['x']+box['width']<=width and box['y']+box['height']<=height
        if width==1920:
            Path('.codex-log').mkdir(exist_ok=True)
            page.screenshot(path='.codex-log/inventory-attachments.png')
        page.keyboard.press('Escape')
    assert not errors, errors
    browser.close()
print('PASS: attachment hover, individual removal, reuse, transfer and five viewport sizes')
