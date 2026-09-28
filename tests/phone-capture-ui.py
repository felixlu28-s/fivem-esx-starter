"""Game WebGL path (not Studio wallpaper), orientation and CEF-safe local saves."""
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(channel='chrome', headless=True)
    page = browser.new_page(viewport={'width': 1920, 'height': 1080})
    errors = []
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.add_init_script('''
      window.persistRequests = 0; window.textureRequests = 0;
      // CEF exposes persist(), but its native permission path can crash the host.
      // Throwing here makes any attempt a regression, even if JS catches it.
      navigator.storage.persist = () => { persistRequests++; throw Error('Unsafe CEF permission request'); };
      const original = WebGLRenderingContext.prototype.texParameterf;
      WebGLRenderingContext.prototype.texParameterf = function(target, parameter, value) {
        original.call(this, target, parameter, value);
        if (parameter === this.TEXTURE_WRAP_T && value === this.REPEAT) {
          textureRequests++;
          // Emulate the Cfx game texture: texture v=1 is the top of the game.
          // Top: red | green. Bottom: blue | yellow. Real shader/readback below.
          const pixels = new Uint8Array(16*16*4);
          for(let y=0;y<16;y++)for(let x=0;x<16;x++)
            pixels.set(y<8 ? (x<8 ? [0,0,255,255] : [255,255,0,255])
              : (x<8 ? [255,0,0,255] : [0,255,0,255]), (y*16+x)*4);
          this.texImage2D(this.TEXTURE_2D,0,this.RGBA,16,16,0,this.RGBA,this.UNSIGNED_BYTE,pixels);
        }
      };
    ''')
    page.goto('http://127.0.0.1:5173/?view=phone', wait_until='networkidle')
    result = page.evaluate('''async () => {
      const {PhoneCapture} = await import('/src/lib/phoneCapture.ts');
      const gallery = await import('/src/lib/phoneGallery.ts');
      const capture = new PhoneCapture(false, 'camera');
      await capture.waitReady();
      const sample = source => {
        const c=document.createElement('canvas');c.width=80;c.height=80;
        const ctx=c.getContext('2d');ctx.drawImage(source,0,0,80,80);
        return [[20,20],[60,20],[20,60],[60,60]].map(([x,y])=>[...ctx.getImageData(x,y,1,1).data]);
      };
      const blobColors = async blob => { const image=await createImageBitmap(blob);try{return sample(image)}finally{image.close()} };
      const photoColors=await blobColors(await capture.snapshot());
      const thumbColors=await blobColors(await capture.thumbnail());
      const video=document.createElement('video');video.muted=true;video.srcObject=capture.video();await video.play();
      await new Promise(resolve=>setTimeout(resolve,180));
      const previewColors=sample(video);
      let saveError='';
      try { await gallery.takeLocalPhoto('capture-regression',capture); } catch(e) { saveError=e.message; }
      const recording=gallery.recordLocalVideo('capture-regression',capture);
      await new Promise(resolve=>setTimeout(resolve,600));recording.stop();
      try { await recording.finished; } catch(e) { saveError += ' '+e.message; }
      capture.close();capture.close();video.srcObject=null;
      const stored=await gallery.listLocalMedia('capture-regression');
      const savedPhoto=stored.items.find(item=>item.kind==='photo');
      const savedColors=savedPhoto?await blobColors((await gallery.loadLocalMedia('capture-regression',savedPhoto.id)).blob):null;
      const call=new PhoneCapture(false,'call');await call.waitReady();
      const callColors=await blobColors(await call.snapshot());const stream=call.video();call.close();
      return {photoColors,thumbColors,previewColors,savedColors,callColors,saveError,
        persistRequests,textureRequests,stored:stored.items.length,stopped:stream.getTracks().every(t=>t.readyState==='ended')};
    }''')
    problems = []
    for name in ['photoColors', 'thumbColors', 'previewColors', 'savedColors', 'callColors']:
        colors = result[name]
        if not colors or not (colors[0][0] > 220 and colors[0][1] < 30 and colors[0][2] < 30
                and colors[1][1] > 220 and colors[1][0] < 30 and colors[1][2] < 30
                and colors[2][2] > 220 and colors[2][0] < 30 and colors[2][1] < 30
                and colors[3][0] > 220 and colors[3][1] > 220 and colors[3][2] < 30):
            problems.append((name, colors))
    if result['persistRequests'] or result['saveError']:
        problems.append(('unsafe storage permission request', result['persistRequests'], result['saveError']))
    assert not problems, problems
    assert result['textureRequests'] == 2 and result['stored'] == 2 and result['stopped'], result
    assert not errors, errors
    browser.close()
print('PASS: real WebGL game-path preview/photo/thumbnail/call orientation, local photo+video without CEF permission requests, stream cleanup')
