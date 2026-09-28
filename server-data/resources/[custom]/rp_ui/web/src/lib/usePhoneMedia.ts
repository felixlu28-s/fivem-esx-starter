import { useEffect, useRef, useState } from "react";
import { fetchNui, isNuiMessage } from "./nui";
import { PhoneCapture } from "./phoneCapture";
import type { PhoneCall, PhoneSignal } from "./phoneData";
type Peer = { pc: RTCPeerConnection; call: string; pending: RTCIceCandidateInit[]; sender: RTCRtpSender | null };
export function usePhoneMedia(session: string, open: boolean, available: boolean, preview: boolean, cameraApp = false) {
  const [call,setCall]=useState<PhoneCall|false>(false);
  const [mode,setMode]=useState<"off"|"rear"|"selfie">("off");
  const [zoom,setZoom]=useState(1);
  const cameraCommands=useRef(Promise.resolve());
  const [capture,setCapture]=useState<PhoneCapture|null>(null);
  const [streams,setStreams]=useState<Record<number,MediaStream>>({});
  const [error,setError]=useState("");
  const [notice,setNotice]=useState(0);
  const [hasMessage,setHasMessage]=useState(false);
  const ref=useRef({call,session,open,capture}); ref.current={call,session,open,capture};
  const peers=useRef(new Map<number,Peer>());
  const previousCall=useRef(false);
  useEffect(()=>{if(previousCall.current&&!call)setMode("off");previousCall.current=!!call;},[!!call]);
  const transmit=(d:Record<string,unknown>)=>fetchNui("rp_phone:signal",d).catch(()=>undefined);
  const remove=(id:number)=>{const peer=peers.current.get(id);peer?.pc.close();peers.current.delete(id);setStreams((old)=>{const next={...old};delete next[id];return next;});};
  const getPeer=(id:number,c:PhoneCall):Peer=>{
    const old=peers.current.get(id);if(old?.call===c.id)return old;if(old)remove(id);
    const pc=new RTCPeerConnection({iceServers:c.ice,bundlePolicy:"max-bundle"});
    // Only the offerer creates a transceiver. The answerer must reuse the one
    // created by setRemoteDescription, otherwise its camera stays unnegotiated.
    const sender=c.self<id?pc.addTransceiver("video",{direction:"sendrecv"}).sender:null;
    const peer:Peer={pc,call:c.id,pending:[],sender};peers.current.set(id,peer);
    pc.onicecandidate=({candidate})=>{if(candidate)void transmit({call:c.id,target:id,type:"candidate",candidate:candidate.candidate,mid:candidate.sdpMid??"0",line:candidate.sdpMLineIndex??0});};
    pc.ontrack=({track})=>{if(track.kind==="video")setStreams((old)=>({...old,[id]:new MediaStream([track])}));};
    pc.onconnectionstatechange=()=>{
      if(pc.connectionState==="failed")setError("Videoverbindung fehlgeschlagen. Für manche Netzwerke benötigt der Server einen TURN-Zugang.");
      if(pc.connectionState==="connected"&&peer.sender){
        const params=peer.sender.getParameters();
        if(params.encodings.length){for(const encoding of params.encodings){encoding.maxBitrate=300000;encoding.maxFramerate=12;}void peer.sender.setParameters(params).catch(()=>undefined);}
      }
    };
    return peer;
  };
  const receive=async(d:PhoneSignal)=>{
    const c=ref.current.call;
    if(!c||c.id!==d.call||!c.members.some((m)=>m.id===d.from&&m.joined))return;
    const peer=getPeer(d.from,c);
    if(d.type==="candidate"){
      const candidate={candidate:d.candidate,sdpMid:d.mid??"0",sdpMLineIndex:d.line};
      if(peer.pc.remoteDescription)await peer.pc.addIceCandidate(candidate);else if(peer.pending.length<80)peer.pending.push(candidate);
      return;
    }
    await peer.pc.setRemoteDescription({type:d.type,sdp:d.sdp});
    if(ref.current.call===false||ref.current.call.id!==c.id||peers.current.get(d.from)!==peer)return;
    if(d.type==="offer"){
      const transceiver=peer.pc.getTransceivers().find((t)=>t.receiver.track.kind==="video");
      if(!transceiver)return;
      transceiver.direction="sendrecv";peer.sender=transceiver.sender;
    }
    const mine=c.members.find((m)=>m.id===c.self);
    await peer.sender?.replaceTrack(mine?.video?ref.current.capture?.video().getVideoTracks()[0]??null:null);
    for(const candidate of peer.pending.splice(0))await peer.pc.addIceCandidate(candidate);
    if(d.type==="offer"){
      await peer.pc.setLocalDescription(await peer.pc.createAnswer());
      await transmit({call:c.id,target:d.from,type:"answer",sdp:peer.pc.localDescription!.sdp});
    }
  };
  const receiveRef=useRef(receive);receiveRef.current=receive;
  useEffect(()=>{
    const listener=(e:MessageEvent<unknown>)=>{
      if(!isNuiMessage(e.data)||e.data.action!=="ui:phoneApp")return;
      const d=e.data.data;
      if(d.kind==="call"){ref.current.call=d.call;setCall(d.call);setError("");}
      if(d.kind==="message"){setNotice((n)=>n+1);setHasMessage(true);}
      if(d.kind==="reset"){ref.current.call=false;setCall(false);setNotice(0);setHasMessage(false);setMode("off");}
      if(d.kind==="signal")void receiveRef.current(d).catch(()=>{if(ref.current.call&&ref.current.call.id===d.call)setError("Die Videoverbindung konnte nicht hergestellt werden.");});
    };
    window.addEventListener("message",listener);return()=>window.removeEventListener("message",listener);
  },[]);
  const mine=call&&call.members.find((m)=>m.id===call.self);
  useEffect(()=>{if(mine&&mine.joined&&mine.video&&open)setMode("selfie");else if(!open||!available||call)setMode("off");},[mine&&mine.video,mine&&mine.joined,open,available,!!call]);
  const cameraActive=mode!=="off"&&open&&available;
  useEffect(()=>{if(preview)capture?.previewLens(zoom,mode==="selfie");},[zoom,mode,capture,preview]);
  useEffect(()=>{
    if(preview)return;
    let cancelled=false;
    // Ordered local native commands avoid a delayed close overtaking a new lens.
    cameraCommands.current=cameraCommands.current.catch(()=>undefined).then(async()=>{
      if(cancelled)return;
      let r=await fetchNui("rp_phone:camera",{session,mode:cameraActive?mode:"off",zoom});
      // The phone opening animation takes 750 ms before the held prop is ready.
      for(let attempt=0;!cancelled&&cameraActive&&!r.ok&&r.error==="invalid_state"&&attempt<6;attempt++){
        await new Promise((resolve)=>window.setTimeout(resolve,150));
        if(cancelled)return;
        r=await fetchNui("rp_phone:camera",{session,mode,zoom});
      }
      if(!cancelled&&cameraActive&&!r.ok)throw new Error("Spielkamera momentan nicht verfügbar.");
    });
    void cameraCommands.current.catch((e:unknown)=>{if(!cancelled)setError(e instanceof Error?e.message:"Kamerafehler");});
    return()=>{cancelled=true;};
  },[mode,zoom,cameraActive,session,preview]);
  useEffect(()=>{
    if(!cameraActive)return;
    let cancelled=false,instance:PhoneCapture|null=null;
    void (async()=>{
      await cameraCommands.current;
      await new Promise((resolve)=>window.setTimeout(resolve,350));
      if(cancelled)return;
      instance=new PhoneCapture(preview,cameraApp?"camera":"call");await instance.waitReady();if(!cancelled)setCapture(instance);
    })().catch((e:unknown)=>{instance?.close();instance=null;if(!cancelled)setError(e instanceof Error?e.message:"Kamerafehler");});
    return()=>{cancelled=true;instance?.close();setCapture(null);};
  },[cameraActive,cameraApp,session,preview]);
  useEffect(()=>()=>{
    if(!preview)cameraCommands.current=cameraCommands.current.catch(()=>undefined).then(async()=>{await fetchNui("rp_phone:camera",{session,mode:"off"});}).catch(()=>undefined);
  },[session,preview]);
  useEffect(()=>{
    if(!call||!available){for(const id of peers.current.keys())remove(id);return;}
    const me=call.members.find((m)=>m.id===call.self);
    const targets=me?.joined?call.members.filter((m)=>m.id!==call.self&&m.joined&&(me.video||m.video)):[];
    for(const id of peers.current.keys())if(!targets.some((m)=>m.id===id))remove(id);
    if(preview)return;
    for(const m of targets){
      const fresh=!peers.current.has(m.id),peer=getPeer(m.id,call);
      void peer.sender?.replaceTrack(me?.video?capture?.video().getVideoTracks()[0]??null:null).catch(()=>undefined);
      if(fresh&&call.self<m.id)void(async()=>{
        await peer.pc.setLocalDescription(await peer.pc.createOffer());
        await transmit({call:call.id,target:m.id,type:"offer",sdp:peer.pc.localDescription!.sdp});
      })().catch(()=>setError("Videoverbindung konnte nicht aufgebaut werden."));
    }
  },[call,capture,available,preview]);
  useEffect(()=>()=>{for(const p of peers.current.values())p.pc.close();peers.current.clear();},[]);
  return {call,setCall,mode,setMode,zoom,setZoom,capture,streams,error,setError,notice,hasMessage,setHasMessage};
}
export type PhoneMedia = ReturnType<typeof usePhoneMedia>;
