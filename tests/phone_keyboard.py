"""Drive the phone through real key presses; no DOM clicks or state injection."""
from playwright.sync_api import expect


class PhoneKeyboard:
    def __init__(self, page):
        self.page = page

    def press(self, key):
        self.page.keyboard.press(key)
        self.page.wait_for_timeout(145)

    def select(self, label):
        page = self.page
        # Locate by accessible label, including icon-only actions.
        target = page.locator('[data-phone-action]').and_(page.get_by_role('button', name=label, exact=True))
        expect(target).to_have_count(1)
        target_id = target.get_attribute('data-phone-action')
        for _ in range(180):
            rows = page.locator('.comm-controls').evaluate_all('(rows)=>rows.map(r=>[...r.children].filter(c=>c.dataset.phoneAction).map(c=>({id:c.dataset.phoneAction,selected:c.getAttribute("aria-pressed")==="true"})))')
            location = [(r, c) for r, row in enumerate(rows) for c, action in enumerate(row) if action['id'] == target_id][0]
            current = [(r, c) for r, row in enumerate(rows) for c, action in enumerate(row) if action['selected']]
            if not current:
                self.press('ArrowUp')
                continue
            r, c = current[0]
            if (r, c) == location:
                expect(target).not_to_have_attribute('aria-disabled', 'true')
                return target
            if r != location[0]:
                self.press('ArrowDown' if r < location[0] else 'ArrowUp')
            else:
                self.press('ArrowRight' if c < location[1] else 'ArrowLeft')
        raise AssertionError(f'Cannot reach {label}')

    def choose(self, label):
        self.select(label)
        self.press('Enter')
        self.page.wait_for_timeout(450)

    def home(self):
        for _ in range(10):
            if self.page.locator('.phone-device').get_attribute('data-page') == 'home':
                return
            self.press('Backspace')
        raise AssertionError('Cannot return home')

    def app(self, label):
        self.home()
        labels = self.page.locator('.phone-app>span:last-child').all_text_contents()
        current = self.page.locator('.phone-app').evaluate_all('(rows)=>rows.findIndex(r=>r.getAttribute("aria-selected")==="true")')
        target = labels.index(label)
        for _ in range(abs(current - target)):
            self.press('ArrowRight' if target > current else 'ArrowLeft')
        self.press('Enter')
        self.page.wait_for_timeout(700)

    def fill(self, values):
        for label, value in values.items():
            self.page.get_by_label(label, exact=True).fill(value)
        self.press('Enter')
        expect(self.page.locator('.phone-form')).to_have_count(0)
        self.page.wait_for_timeout(650)
