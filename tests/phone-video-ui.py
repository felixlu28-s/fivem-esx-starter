"""Real WebRTC mesh through the phone NUI bridge; no webcam, microphone or GTA claim."""
import asyncio
from playwright.async_api import async_playwright


async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(channel='chrome', headless=True)
        pages, errors, signals = {}, [], []
        for player in (1, 2, 3):
            page = await browser.new_page(viewport={'width': 1920, 'height': 1080})
            pages[player] = page
            page.on('pageerror', lambda error: errors.append(str(error)))
            await page.add_init_script('''
                window.GetParentResourceName=()=>"rp_ui";
                window.testPeers=[]; window.testTracks=[];
                const Original=window.RTCPeerConnection;
                window.RTCPeerConnection=class extends Original {
                    constructor(config) { super(config); window.testPeers.push(this);
                        this.addEventListener('track', e=>window.testTracks.push(e.track)); }
                };
                navigator.mediaDevices.getUserMedia=()=>{throw Error('Phone must never request webcam/microphone');};
            ''')

            async def route(r, _request, player=player):
                action = r.request.url.rsplit('/', 1)[-1]
                data = r.request.post_data_json
                result = {'ok': True}
                if action == 'rp_phone:action':
                    if data['action'] == 'home':
                        result['phone'] = {'kind': 'home', 'profile': {
                            'id': player, 'number': f'555{player:07}', 'name': f'Player {player}',
                            'handle': f'player{player}', 'bio': '', 'contacts': [], 'tasks': [], 'bookmarks': []}, 'sites': []}
                    elif data['action'] == 'history':
                        result['phone'] = {'kind': 'history', 'rows': []}
                if action == 'rp_phone:signal':
                    signals.append(data)
                    target = pages[data['target']]
                    await target.evaluate('(data)=>window.postMessage({action:"ui:phoneApp",data},"*")',
                        {**data, 'kind': 'signal', 'from': player})
                await r.fulfill(json=result)

            await page.route('https://rp_ui/**', route)
            await page.goto('http://127.0.0.1:5173/?view=phone', wait_until='networkidle')
            await page.evaluate('window.postMessage({action:"ui:phone",data:{available:true,open:true,session:"media-test",toggleKey:"UP"}},"*")')

        async def publish(ids, camera_off=()):
            members = [{'id': i, 'number': f'555{i:07}', 'name': f'Player {i}',
                        'joined': True, 'video': i not in camera_off, 'muted': False} for i in ids]
            await asyncio.gather(*(pages[i].evaluate('(call)=>window.postMessage({action:"ui:phoneApp",data:{kind:"call",call}},"*")',
                {'id': 'mesh-test', 'self': i, 'host': 1, 'video': True, 'backend': 'mumble', 'members': members, 'ice': []}) for i in ids))

        await publish([1, 2, 3])
        for page in pages.values():
            await page.wait_for_function('testPeers.length===2 && testPeers.every(p=>p.connectionState==="connected")', timeout=20000)
            try:
                await page.wait_for_function('testTracks.length===2 && testTracks.every(t=>t.kind==="video" && !t.muted)', timeout=15000)
            except Exception:
                for debug_page in pages.values():
                    print(await debug_page.evaluate('''async()=>({tracks:testTracks.map(t=>({muted:t.muted,state:t.readyState})),
                        peers:await Promise.all(testPeers.map(async p=>({state:p.connectionState,transceivers:p.getTransceivers().map(t=>({mid:t.mid,direction:t.direction,current:t.currentDirection,track:t.sender.track?.readyState})),
                            stats:[...await p.getStats()].filter(s=>s.type==='outbound-rtp'||s.type==='inbound-rtp').map(s=>({type:s.type,bytesSent:s.bytesSent,bytesReceived:s.bytesReceived,framesEncoded:s.framesEncoded}))}))),
                        error:document.querySelector('.phone-app-error')?.textContent})'''))
                raise
            assert await page.evaluate('testPeers.every(p=>p.getSenders().every(s=>!s.track || s.track.kind==="video"))')
            await page.wait_for_function('testPeers.every(p=>p.getSenders().some(s=>s.track?.readyState==="live"))')
        assert any(s['type'] == 'offer' for s in signals) and any(s['type'] == 'answer' for s in signals)

        # Camera changes reuse negotiated connections; audio-only members still receive video.
        await publish([1, 2, 3], camera_off=(3,))
        await pages[3].wait_for_function('testPeers.every(p=>p.getSenders().every(s=>!s.track))')
        await publish([1, 2, 3])
        await pages[3].wait_for_function('testPeers.every(p=>p.getSenders().some(s=>s.track?.readyState==="live"))')
        for page in pages.values():
            await page.evaluate('window.sentTracks=testPeers.flatMap(p=>p.getSenders().map(s=>s.track).filter(Boolean))')

        # Member departure closes just that pair; remaining conference stays connected.
        await pages[3].evaluate('window.postMessage({action:"ui:phoneApp",data:{kind:"call",call:false}},"*")')
        await publish([1, 2])
        for i in (1, 2):
            await pages[i].wait_for_function('testPeers.filter(p=>p.connectionState==="connected").length===1 && testPeers.filter(p=>p.connectionState==="closed").length===1')
        await pages[3].wait_for_function('testPeers.every(p=>p.connectionState==="closed")')
        await pages[3].wait_for_function('sentTracks.every(t=>t.readyState==="ended")')
        for i in (1, 2):
            await pages[i].evaluate('window.postMessage({action:"ui:phoneApp",data:{kind:"call",call:false}},"*")')
            await pages[i].wait_for_function('testPeers.every(p=>p.connectionState==="closed")')
            await pages[i].wait_for_function('sentTracks.every(t=>t.readyState==="ended")')
        assert not errors, errors
        await browser.close()
    print('phone-video-ui: 3-peer real video mesh, no webcam/audio tracks, participant departure and hangup cleanup passed')


asyncio.run(main())
