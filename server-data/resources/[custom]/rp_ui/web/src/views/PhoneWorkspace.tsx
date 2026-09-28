import { forwardRef, useEffect, useImperativeHandle, useRef, useState, type ReactNode } from "react";
import { PhoneForm, type PhoneField, type PhoneFormState } from "../components/PhoneForm";
import { phoneRequest } from "../lib/phoneRequest";
import type { PhoneApp, PhoneKey } from "../lib/phone";
import type { PhoneProfile, PhoneReply, PhoneTask } from "../lib/phoneData";
import type { PhoneMedia } from "../lib/usePhoneMedia";
export type PhoneWorkspaceHandle={key:(key:PhoneKey)=>boolean};
type Props={app:PhoneApp;session:string;preview:boolean;open:boolean;focused:boolean;media:PhoneMedia;launch:(app:PhoneApp)=>void};
type Screen={kind:"root"|"task";task?:PhoneTask};
type Field=PhoneField;
type Form=PhoneFormState;
type Row={id:string;label:string;detail?:string;danger?:boolean;disabled?:boolean;photo?:number;run:()=>void};
const nonce=()=>crypto.randomUUID();
const date=(n:number)=>new Date(n*1000).toLocaleString("de-DE",{day:"2-digit",month:"2-digit",hour:"2-digit",minute:"2-digit"});
const errors:Record<string,string>={busy:"Einen Moment bitte.",limit:"Der verfügbare Speicher oder die Teilnehmergrenze ist erreicht.",unknown_number:"Diese Nummer existiert nicht.",number_unavailable:"Nicht erreichbar oder bereits im Gespräch.",photo_published:"Entferne zuerst den dazugehörigen iFruit-Beitrag.",handle_taken:"Dieser Benutzername ist bereits vergeben.",invalid_fields:"Bitte prüfe die Eingaben.",voice_conflict:"Die aktive Voice-Resource benötigt einen Telefonadapter.",rate_limited:"Bitte kurz warten.",invalid_state:"Handy bitte schließen und erneut öffnen.",unavailable:"Handydienst momentan nicht verfügbar."};
export const PhoneWorkspace=forwardRef<PhoneWorkspaceHandle,Props>(function PhoneWorkspace({app,session,preview,open,focused,media,launch},ref){
  const [profile,setProfile]=useState<PhoneProfile|null>(null);
  const [screen,setScreen]=useState<Screen>({kind:"root"}),[stack,setStack]=useState<Screen[]>([]),[selected,setSelected]=useState(0);
  const [form,setForm]=useState<Form|null>(null);
  const [error,setError]=useState(""),[busy,setBusy]=useState(false);
  const busyRef=useRef(false),generation=useRef(0),alive=useRef(true),root=useRef<HTMLDivElement>(null);
  const apply=(data?:PhoneReply)=>{if(!data)return;switch(data.kind){
    case "home":setProfile(data.profile);break;
  }};
  const request=async(action:string,data:Record<string,unknown>={})=>{
    const result=await phoneRequest(session,preview,action,data);
    if(!result.ok)throw new Error(errors[result.error??""]??"Diese Aktion ist gerade nicht möglich.");
    if(alive.current)apply(result.phone);return result.phone;
  };
  const run=(action:()=>Promise<void>)=>{
    if(busyRef.current)return;busyRef.current=true;setBusy(true);setError("");
    void action().catch((e:unknown)=>{if(alive.current)setError(e instanceof Error?e.message:"Fehler");}).finally(()=>{busyRef.current=false;if(alive.current)setBusy(false);});
  };
  const go=(next:Screen)=>{setStack((s)=>[...s,screen]);setScreen(next);setSelected(0);};
  const back=()=>{if(stack.length){setScreen(stack[stack.length-1]);setStack((s)=>s.slice(0,-1));setSelected(0);return true;}return false;};
  const edit=(title:string,fields:Field[],save:Form["save"])=>setForm({title,fields,save,nonce:nonce(),submitLabel:"Bestätigen"});
  const textField=(key:string,label:string,value="",max=60,multiline=false):Field=>({key,label,value,max,multiline});
  const confirm=(title:string,save:()=>Promise<void>)=>edit(title,[],save);
  useEffect(()=>{alive.current=true;return()=>{alive.current=false;generation.current++;};},[session,preview]);
  useEffect(()=>{void request("home").catch((e:unknown)=>setError(e instanceof Error?e.message:"Fehler"));},[]);
  useEffect(()=>{root.current?.querySelector(".phone-action.selected")?.scrollIntoView({block:"nearest"});},[selected,screen.kind]);
  const rows:Row[]=[];
  const add=(id:string,label:string,run:()=>void,detail?:string,danger=false,disabled=false)=>rows.push({id,label,run,detail,danger,disabled});
  let content:ReactNode=null;
  if(screen.kind==="task"&&screen.task){const t=screen.task;
    content=<div className="phone-person"><strong>{t.title}</strong></div>;
    add("done",t.done?"Als offen markieren":"Erledigt",()=>run(async()=>{await request("task",{...t,done:!t.done});back();}));
    add("edit","Aufgabe bearbeiten",()=>edit("Aufgabe",[textField("title","Titel",t.title,120)],async(v)=>{await request("task",{...t,title:v.title});back();}));
    add("delete","Aufgabe löschen",()=>confirm("Aufgabe löschen?",async()=>{await request("task",{id:t.id,delete:true});back();}),undefined,true);
  }else if(app==="tasks"){
    add("new","Neue Aufgabe",()=>edit("Aufgabe",[textField("title","Was möchtest du erledigen?","",120)],async(v,requestId)=>{await request("task",{id:requestId,title:v.title,done:false});}));
    for(const t of profile?.tasks??[])add(t.id,`${t.done?"✓":"○"} ${t.title}`,()=>go({kind:"task",task:t}),t.done?"Erledigt":"Offen");
  }
  useImperativeHandle(ref,()=>({key:(key)=>{
    if(form)return true;
    if(key==="back"){return back();}
    if(key==="down"){if(selected>=rows.length-1)return false;setSelected((n)=>n+1);return true;}
    if(key==="up"){setSelected((n)=>Math.max(0,n-1));return true;}
    if(key==="enter"){const row=rows[Math.min(selected,rows.length-1)];if(row&&!row.disabled&&!busyRef.current)row.run();return true;}
    return key==="left"||key==="right";
  }}));
  const submit=()=>{if(!form||busyRef.current)return;const values=Object.fromEntries(form.fields.map((f)=>[f.key,f.value]));run(async()=>{await form.save(values,form.nonce);if(alive.current)setForm((current)=>current?.nonce===form.nonce?null:current);});};
  return <div className="phone-workspace" ref={root}>
    <div className="phone-own-number">{preview?"Browservorschau · ":""}{profile?.number??"Verbinden …"}</div>
    {(error||media.error)&&<div className="phone-app-error" role="status">{error||media.error}</div>}
    {form?<PhoneForm form={form} setForm={setForm} busy={busy} submit={submit} session={session} preview={preview} active={open}/>
      :<>{content}<div className="phone-actions" role="listbox" aria-label="App-Aktionen">{rows.map((row,index)=><div key={row.id} role="option" aria-selected={focused&&Math.min(selected,rows.length-1)===index} aria-disabled={row.disabled||busy} className={`phone-action ${focused&&Math.min(selected,rows.length-1)===index?"selected":""} ${row.danger?"danger":""}`}><span>{row.label}</span>{row.detail&&<small>{row.detail}</small>}</div>)}</div><small className="phone-controls">↑ ↓ Auswählen · Enter · Zurück</small></>}
  </div>;
});
