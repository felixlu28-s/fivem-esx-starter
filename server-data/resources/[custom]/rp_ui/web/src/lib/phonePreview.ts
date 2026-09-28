import { phoneSocialPreview } from "./phoneSocialPreview";
import type { ActionResult } from "./nui";
import type { PhoneProfile, PhoneMessage, PhonePhoto, PhoneCall, PhoneSite, PhoneHistory } from "./phoneData";
let next=10;
const profile:PhoneProfile={id:1,galleryScope:"browser-preview:1",number:"5550000001",name:"Test Joost",handle:"test_joost",bio:"Los Santos. Ein neuer Anfang.",contacts:[],tasks:[],bookmarks:[]};
const sites:PhoneSite[]=[{id:"eyefind",title:"Eyefind",url:"eyefind.info",body:"Entdecke Los Santos. Dein Weg durch die Stadt."},{id:"city",title:"Los Santos City",url:"los-santos.gov",body:"Willkommen in Los Santos. Garagen und Geschäfte findest du auf deiner Karte."},{id:"news",title:"Weazel News",url:"weazel.news",body:"Geschichten aus der Stadt findest du im iFruit-Feed."}];
const messages:PhoneMessage[]=[],photos:PhonePhoto[]=[];
const history:PhoneHistory[]=[];
// Studio-only fixtures. The live phone always obtains its own character data from the server.
if (new URLSearchParams(location.search).get("phoneDemo") !== "0") {
  const now=Math.floor(Date.now()/1000);
  profile.contacts.push({id:"demo-lena",name:"Lena Fischer",number:"5550000002"},{id:"demo-marc",name:"Marc Weber",number:"5550000003"},{id:"demo-sofia",name:"Sofia Costa",number:"5550000004"},{id:"demo-toni",name:"Toni Berger",number:"5550000005"});
  messages.push({id:9,number:"5550000002",body:"Bin gleich da. Treffen wir uns am Pier?",created:now-120,mine:false,seen:false},
    {id:8,number:"5550000002",body:"Klingt gut! Ich hole vorher noch den Wagen ab.",created:now-240,mine:true,seen:true},
    {id:7,number:"5550000002",body:"Hey! Lust auf eine Runde durch die Stadt?",created:now-360,mine:false,seen:true},
    {id:6,number:"5550000003",body:"Dein Auto ist fertig. Du kannst vorbeikommen.",created:now-3900,mine:false,seen:true},
    {id:5,number:"5550000004",body:"Danke, bis morgen!",created:now-86400,mine:true,seen:true});
  history.push({id:4,peer:"5550000002",direction:"in",outcome:"missed",video:false,created:now-300},
    {id:3,peer:"5550000003",direction:"out",outcome:"finished",video:false,created:now-4000},
    {id:2,peer:"5550000004",direction:"in",outcome:"finished",video:true,created:now-8000},
    {id:1,peer:"5550000002",direction:"out",outcome:"finished",video:false,created:now-86400});
}
let call:PhoneCall|false=false;
const event=()=>window.postMessage({action:"ui:phoneApp",data:{kind:"call",call}},"*");
export async function phonePreview(action:string,d:Record<string,unknown>):Promise<ActionResult>{
  const now=Math.floor(Date.now()/1000),str=(key:string)=>String(d[key]??""),id=Number(d.id);
  switch(action){
    case "home":return {ok:true,phone:{kind:"home",profile:structuredClone(profile),unread:0,sites}};
    case "contact":{profile.contacts=profile.contacts.filter((c)=>c.id!==str("id"));if(!d.delete)profile.contacts.push({id:str("id"),name:str("name"),number:str("number")});return phonePreview("home",{});}
    case "task":{profile.tasks=profile.tasks.filter((t)=>t.id!==str("id"));if(!d.delete)profile.tasks.push({id:str("id"),title:str("title"),done:d.done===true});return phonePreview("home",{});}
    case "bookmark":profile.bookmarks=profile.bookmarks.includes(str("id"))?profile.bookmarks.filter((v)=>v!==str("id")):[...profile.bookmarks,str("id")];return phonePreview("home",{});
    case "conversations":{const peers=[...new Set(messages.map((m)=>m.number))];const rows=peers.map((number)=>({...messages.find((m)=>m.number===number)!,unread:messages.filter((m)=>m.number===number&&!m.mine&&!m.seen).length})).filter((m)=>!d.before||m.id<Number(d.before));return {ok:true,phone:{kind:"conversations",rows:rows.slice(0,30),more:rows.length>=30}};}
    case "messages":{const rows=messages.filter((m)=>(!d.number||m.number===d.number)&&(!d.before||m.id<Number(d.before)));return {ok:true,phone:{kind:"messages",rows:rows.slice(0,30),number:str("number"),more:rows.length>=30}};}
    case "send":messages.unshift({id:next++,number:str("number"),body:str("body"),mine:true,seen:false,created:now});return {ok:true};
    case "read":for(const m of messages)if(m.number===d.number&&!m.mine&&m.id<=Number(d.last))m.seen=true;return {ok:true};
    case "photos":return {ok:true,phone:{kind:"photos",rows:[...photos]}};
    case "photo":return {ok:false,error:"local_gallery"};
    case "publish_local": case "image": case "profile": case "feed": case "post": case "post_delete": case "like": case "follow": case "comments": case "comment":
    case "social_home": case "social_create": case "social_switch": case "social_profile": case "social_search": case "social_people":
      return phoneSocialPreview(action,d);
    case "photo_delete": return {ok:false,error:"local_gallery"};
    case "history":return {ok:true,phone:{kind:"history",rows:history.slice(0,30)}};
    case "call_start":call={id:"preview-call",self:1,host:1,backend:"mumble",video:d.video===true,ice:[],members:[{id:1,number:profile.number,name:profile.name,joined:true,video:d.video===true,muted:false},{id:2,number:str("number"),name:"Browser-Testkontakt",joined:true,video:false,muted:false}]};event();return {ok:true};
    case "call_invite":if(call)call.members.push({id:next++,number:str("number"),name:"Konferenz-Testkontakt",joined:true,video:false,muted:false});event();return {ok:true};
    case "call_state":if(call){call.members[0].video=d.video===true;call.members[0].muted=d.muted===true;}event();return {ok:true};
    case "call_leave":if(call){const current=call;for(const member of current.members.filter((m)=>m.id!==current.self))history.unshift({id:next++,peer:member.number,direction:"out",video:current.video,outcome:"finished",created:now});}call=false;event();return {ok:true};
    default:return {ok:false,error:"unavailable"};
  }
}
