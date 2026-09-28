// Uses FiveM's game texture hook, as used by @citizenfx/three CfxTexture.
// No webcam permission, no screenshot relay, no new renderer dependency.
export class PhoneCapture {
  private readonly canvas = document.createElement("canvas");
  readonly width: number;
  readonly height: number;
  private readonly fps: number;
  ready = false;
  private stop = () => {};
  private stream?: MediaStream;
  private closed = false;
  private previewZoom = 1;
  private previewMirror = false;
  constructor(preview: boolean, quality: "call" | "camera" = "call") {
    this.width=this.canvas.width=quality==="camera"?720:640;
    this.height=this.canvas.height=quality==="camera"?960:360;
    this.fps=quality==="camera"?24:12;
    if (preview) {
      const ctx=this.canvas.getContext("2d")!;
      const img=new Image(); img.src="./phone/wallpaper.png";
      const draw=()=>{if(!img.naturalWidth)return;const scale=Math.max(this.width/img.naturalWidth,this.height/img.naturalHeight)*Math.max(1,this.previewZoom);ctx.save();if(this.previewMirror){ctx.translate(this.width,0);ctx.scale(-1,1);}ctx.drawImage(img,(this.width-img.naturalWidth*scale)/2,(this.height-img.naturalHeight*scale)/2,img.naturalWidth*scale,img.naturalHeight*scale);ctx.restore();this.ready=true;};
      img.onload=draw;
      const timer=window.setInterval(draw,1000/this.fps);
      this.stop=()=>{img.onload=null;window.clearInterval(timer);}; return;
    }
    const gl=this.canvas.getContext("webgl",{alpha:false,preserveDrawingBuffer:true});
    if (!gl) throw new Error("Die Spielkamera ist nicht verfügbar.");
    const shader=(type:number,source:string)=>{
      const s=gl.createShader(type)!; gl.shaderSource(s,source); gl.compileShader(s);
      if (!gl.getShaderParameter(s,gl.COMPILE_STATUS)) { gl.deleteShader(s); gl.getExtension("WEBGL_lose_context")?.loseContext(); throw new Error("Kamera konnte nicht gestartet werden."); }
      return s;
    };
    // Cfx texture v=1 is the top of the game. Canvas display/encoding already
    // handles framebuffer orientation. screenshot-basic's Y flip is only for
    // its raw readPixels -> ImageData path; copying it here inverts every frame.
    const vertex=shader(gl.VERTEX_SHADER,"attribute vec2 p; varying vec2 uv; void main(){uv=(p+1.0)*0.5;gl_Position=vec4(p,0.0,1.0);}");
    const fragment=shader(gl.FRAGMENT_SHADER,"precision mediump float; varying vec2 uv; uniform sampler2D game; uniform vec2 crop; void main(){gl_FragColor=texture2D(game,(uv-0.5)*crop+0.5);}");
    const program=gl.createProgram()!; gl.attachShader(program,vertex);gl.attachShader(program,fragment);gl.linkProgram(program);
    if(!gl.getProgramParameter(program,gl.LINK_STATUS)){gl.deleteProgram(program);gl.deleteShader(vertex);gl.deleteShader(fragment);gl.getExtension("WEBGL_lose_context")?.loseContext();throw new Error("Kamera konnte nicht gestartet werden.");}
    gl.useProgram(program);
    const buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buffer);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([-1,-1,1,-1,-1,1,1,1]),gl.STATIC_DRAW);
    const p=gl.getAttribLocation(program,"p");gl.enableVertexAttribArray(p);gl.vertexAttribPointer(p,2,gl.FLOAT,false,0,0);
    const texture=gl.createTexture();gl.bindTexture(gl.TEXTURE_2D,texture);
    gl.texImage2D(gl.TEXTURE_2D,0,gl.RGB,1,1,0,gl.RGB,gl.UNSIGNED_BYTE,new Uint8Array(3));
    gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.LINEAR);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE);
    // This parameter sequence requests the Cfx shared game texture.
    for (const mode of [gl.CLAMP_TO_EDGE,gl.MIRRORED_REPEAT,gl.REPEAT]) gl.texParameterf(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,mode);
    gl.viewport(0,0,this.width,this.height);
    const crop=gl.getUniformLocation(program,"crop");
    const timer=window.setInterval(()=>{
      const aspect=(this.width/this.height)/(window.innerWidth/window.innerHeight);
      gl.uniform2f(crop,Math.min(1,aspect),Math.min(1,1/aspect));
      gl.drawArrays(gl.TRIANGLE_STRIP,0,4);this.ready=true;
    },1000/this.fps);
    this.stop=()=>{window.clearInterval(timer);gl.deleteTexture(texture);gl.deleteBuffer(buffer);gl.deleteProgram(program);gl.deleteShader(vertex);gl.deleteShader(fragment);gl.getExtension("WEBGL_lose_context")?.loseContext();};
  }
  photo() {
    let quality=.8, data=this.canvas.toDataURL("image/jpeg",quality);
    while (data.length>115000 && quality>.2) { quality-=.1; data=this.canvas.toDataURL("image/jpeg",quality); }
    if (data.length>120000) throw new Error("Das Foto ist zu groß.");
    return data;
  }
  snapshot(): Promise<Blob> {
    if(!this.ready)throw new Error("Die Kamera ist noch nicht bereit.");
    return new Promise((resolve,reject)=>this.canvas.toBlob((blob)=>blob?resolve(blob):reject(new Error("Foto konnte nicht aufgenommen werden.")),"image/jpeg",.88));
  }
  async waitReady() {
    const until=performance.now()+3000;
    while(!this.ready&&!this.closed&&performance.now()<until)await new Promise((resolve)=>window.setTimeout(resolve,50));
    if(!this.ready||this.closed)throw new Error("Die Kameravorschau konnte nicht gestartet werden.");
  }
  previewLens(zoom: number, mirror: boolean) { this.previewZoom=zoom;this.previewMirror=mirror; }
  thumbnail(): Promise<Blob> {
    const canvas=document.createElement("canvas");canvas.width=180;canvas.height=Math.round(180*this.height/this.width);
    canvas.getContext("2d")!.drawImage(this.canvas,0,0,canvas.width,canvas.height);
    return new Promise((resolve,reject)=>canvas.toBlob((blob)=>blob?resolve(blob):reject(new Error("Vorschau konnte nicht erzeugt werden.")),"image/jpeg",.72));
  }
  video() { return this.stream ??= this.canvas.captureStream(this.fps); }
  close() { this.closed=true;this.ready=false;this.stream?.getTracks().forEach((t)=>t.stop());this.stop();this.canvas.remove(); }
}
