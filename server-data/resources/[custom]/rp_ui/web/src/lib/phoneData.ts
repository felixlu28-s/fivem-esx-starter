export type Contact = { id: string; name: string; number: string };
export type PhoneTask = { id: string; title: string; done: boolean };
export type PhoneProfile = { id: number; number: string; name: string; handle: string; bio: string; galleryScope?: string; contacts: Contact[]; tasks: PhoneTask[]; bookmarks: string[] };
export type PhoneSite = { id: string; title: string; url: string; body: string };
export type PhoneMessage = { id: number; number: string; body: string; created: number; mine: boolean; seen: boolean };
export type PhoneConversation = PhoneMessage & { unread: number };
export type PhonePhoto = { id: number; created: number };
export type PhonePost = { id: number; author: number; photo: number; caption: string; created: number; name: string; handle: string; likes: number; liked: boolean; following: boolean; comments: number };
export type PhoneComment = { id: number; body: string; created: number; name: string; author?: number; handle?: string };
export type SocialIdentity = { id: number; name: string; handle: string; bio: string; slot: number };
export type SocialProfile = Omit<SocialIdentity, "slot"> & { posts: number; followers: number; follows: number; following: boolean };
export type SocialAccount = { profiles: SocialIdentity[]; active: number; slots: number };
export type PhoneHistory = { id: number; peer: string; direction: string; video: number | boolean; outcome: string; created: number };
export type PhoneReply =
  | { kind: "home"; profile: PhoneProfile; unread?: number; sites?: PhoneSite[] }
  | { kind: "messages"; rows: PhoneMessage[]; number: string; more: boolean }
  | { kind: "conversations"; rows: PhoneConversation[]; more: boolean }
  | { kind: "photos"; rows: PhonePhoto[] }
  | { kind: "image"; id: number; image: string }
  | { kind: "feed"; rows: PhonePost[]; more: boolean }
  | { kind: "comments"; rows: PhoneComment[]; more?: boolean }
  | { kind: "social_home" } & SocialAccount
  | { kind: "social_profile"; profile: SocialProfile }
  | { kind: "social_people"; rows: SocialProfile[]; more: boolean }
  | { kind: "history"; rows: PhoneHistory[] };
export type PhoneMember = { id: number; number: string; name: string; joined: boolean; video: boolean; muted: boolean };
export type PhoneCall = { id: string; self: number; host: number; video: boolean; backend: "native" | "mumble"; members: PhoneMember[]; ice: RTCIceServer[] };
export type PhoneSignal = { kind: "signal"; call: string; from: number } & (
  { type: "offer" | "answer"; sdp: string } | { type: "candidate"; candidate: string; mid?: string; line: number });
export type PhoneEvent = { kind: "call"; call: PhoneCall | false } | PhoneSignal | { kind: "message" | "reset" };
const obj = (v: unknown): v is Record<string, unknown> => !!v && typeof v === "object" && !Array.isArray(v);
const str = (v: unknown, n = 1000): v is string => typeof v === "string" && v.length <= n;
const num = (v: unknown): v is number => typeof v === "number" && Number.isSafeInteger(v) && v >= 0;
const bool = (v: unknown): v is boolean => typeof v === "boolean";
const list = (v: unknown, n: number, check: (r: Record<string, unknown>) => boolean) => Array.isArray(v) && v.length <= n && v.every((r) => obj(r) && check(r));
const socialIdentity = (v: Record<string, unknown>) => num(v.id) && v.id > 0 && str(v.name,60) && str(v.handle,24) && str(v.bio,160);
const socialProfile = (v: Record<string, unknown>) => socialIdentity(v) && num(v.posts) && num(v.followers) && num(v.follows) && bool(v.following);
export function parsePhoneReply(v: unknown): PhoneReply | null {
  if (!obj(v)) return null;
  let ok = false;
  switch (v.kind) {
    case "home": { const p = v.profile; ok = obj(p) && num(p.id) && str(p.number,16) && str(p.name,60) && str(p.handle,24) && str(p.bio,160)
      && (p.galleryScope===undefined||(str(p.galleryScope,100)&&/^[a-zA-Z0-9:_-]+$/.test(p.galleryScope)))
      && list(p.contacts,150,(r)=>str(r.id,80)&&str(r.name,60)&&str(r.number,16))
      && list(p.tasks,100,(r)=>str(r.id,80)&&str(r.title,120)&&bool(r.done))
      && Array.isArray(p.bookmarks)&&p.bookmarks.length<=50&&p.bookmarks.every((s)=>str(s,80))
      && (v.unread===undefined||num(v.unread)) && (v.sites===undefined||list(v.sites,50,(s)=>str(s.id,80)&&str(s.title,80)&&str(s.url,160)&&str(s.body,3000))); break; }
    case "messages": ok = str(v.number,16)&&bool(v.more)&&list(v.rows,30,(r)=>num(r.id)&&str(r.number,16)&&str(r.body)&&num(r.created)&&bool(r.mine)&&bool(r.seen)); break;
    case "conversations": ok = bool(v.more)&&list(v.rows,30,(r)=>num(r.id)&&str(r.number,16)&&str(r.body)&&num(r.created)&&bool(r.mine)&&bool(r.seen)&&num(r.unread)); break;
    case "photos": ok = list(v.rows,40,(r)=>num(r.id)&&num(r.created)); break;
    case "image": ok = num(v.id)&&str(v.image,120000)&&v.image.startsWith("data:image/jpeg;base64,/9j/"); break;
    case "feed": ok = bool(v.more)&&list(v.rows,15,(r)=>num(r.id)&&num(r.author)&&num(r.photo)&&str(r.caption)&&num(r.created)&&str(r.name,60)&&str(r.handle,24)&&num(r.likes)&&bool(r.liked)&&bool(r.following)&&num(r.comments)); break;
    case "comments": ok = (v.more===undefined||bool(v.more))&&list(v.rows,30,(r)=>num(r.id)&&str(r.body,400)&&str(r.name,60)&&num(r.created)&&(r.author===undefined||num(r.author))&&(r.handle===undefined||str(r.handle,24))); break;
    case "social_home": ok = num(v.slots)&&v.slots>=1&&v.slots<=5&&num(v.active)&&list(v.profiles,5,(r)=>socialIdentity(r)&&num(r.slot)&&r.slot>=1&&r.slot<=5)
      && (v.active===0||(Array.isArray(v.profiles)&&v.profiles.some((p)=>obj(p)&&p.id===v.active))); break;
    case "social_profile": ok = obj(v.profile)&&socialProfile(v.profile); break;
    case "social_people": ok = bool(v.more)&&list(v.rows,20,socialProfile); break;
    case "history": ok = list(v.rows,30,(r)=>num(r.id)&&str(r.peer,16)&&str(r.direction,4)&&(bool(r.video)||r.video===0||r.video===1)&&str(r.outcome,16)&&num(r.created)); break;
  }
  return ok ? v as PhoneReply : null;
}
export function parsePhoneEvent(v: unknown): PhoneEvent | null {
  if (!obj(v)) return null;
  if (v.kind === "message" || v.kind === "reset") return v as PhoneEvent;
  if (v.kind === "signal" && str(v.call,80) && num(v.from)) {
    if ((v.type === "offer" || v.type === "answer") && str(v.sdp,32000)) return v as PhoneSignal;
    if (v.type === "candidate" && str(v.candidate,1200) && (v.mid===undefined||str(v.mid,50)) && num(v.line) && v.line<20) return v as PhoneSignal;
  }
  if (v.kind !== "call") return null;
  if (v.call === false) return {kind:"call",call:false};
  const c=v.call;
  if (!obj(c)||!str(c.id,80)||!num(c.self)||!num(c.host)||!bool(c.video)||(c.backend!=="native"&&c.backend!=="mumble")
    || !list(c.members,6,(m)=>num(m.id)&&str(m.number,16)&&str(m.name,60)&&bool(m.joined)&&bool(m.video)&&bool(m.muted))
    || !list(c.ice,10,(s)=>(str(s.urls,500)||(Array.isArray(s.urls)&&s.urls.length<=5&&s.urls.every((u)=>str(u,500))))
      &&(s.username===undefined||str(s.username,200))&&(s.credential===undefined||str(s.credential,500)))) return null;
  return v as PhoneEvent;
}
