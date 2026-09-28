from playwright.sync_api import expect
from phone_keyboard import PhoneKeyboard


class LocalPhoneKeyboard(PhoneKeyboard):
    def select(self, label):
        page = self.page
        target = page.get_by_role('button', name=label, exact=True)
        expect(target).to_have_count(1)
        for _ in range(100):
            rows = page.evaluate('''()=>[...document.querySelectorAll('.camera-zoom,.camera-modes,.camera-bottom,.gallery-controls')].map(r=>[...r.children].filter(c=>c.getAttribute('role')==='button').map(c=>({label:c.getAttribute('aria-label'),selected:c.getAttribute('aria-pressed')==='true'})))''')
            location = [(r,c) for r,row in enumerate(rows) for c,a in enumerate(row) if a['label']==label][0]
            selected = [(r,c) for r,row in enumerate(rows) for c,a in enumerate(row) if a['selected']]
            if not selected:
                self.press('ArrowUp'); continue
            r,c = selected[0]
            if (r,c)==location:
                expect(target).not_to_have_attribute('aria-disabled','true')
                return target
            self.press(('ArrowDown' if r<location[0] else 'ArrowUp') if r!=location[0] else ('ArrowRight' if c<location[1] else 'ArrowLeft'))
        raise AssertionError(f'Cannot select {label}')
