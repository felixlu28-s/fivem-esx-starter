import { useEffect, useRef, useState, type CSSProperties } from "react";
import { fetchNui, isBrowser, isNuiMessage } from "../lib/nui";
import { inputKey } from "../lib/menuToggle";
import { appLabel, initialPhone, phoneApps, phoneStep, type PhoneApp, type PhoneKey, type PhonePayload, type PhoneState } from "../lib/phone";
import "../phone.css";
import { PhoneWorkspace, type PhoneWorkspaceHandle } from "./PhoneWorkspace";
import { PhoneCommunication } from "./PhoneCommunication";
import { PhoneCamera } from "./PhoneCamera";
import { PhoneGallery } from "./PhoneGallery";
import { PhoneSocial } from "./PhoneSocial";
import { usePhoneMedia } from "../lib/usePhoneMedia";
import { UiIcon } from "../components/UiIcon";

function Fruit() {
  return <svg viewBox="0 0 40 42" aria-hidden="true"><path fill="currentColor" d="M5 23h30a15 15 0 0 1-30 0m1-4a14 14 0 0 1 27 0H6m14-7c-1-8 6-11 14-10-2 7-8 10-14 10" /><path d="M17 5c4 1 6 4 7 8" fill="none" stroke="currentColor" strokeWidth="2" /></svg>;
}
function AppIcon({ app }: { app: PhoneApp }) {
  if (app === "calls") return <span className="phone-app-icon phone-calls-icon"><UiIcon name="call" /></span>;
  if (app === "gallery") return <span className="phone-app-icon phone-gallery-icon"><UiIcon name="gallery" /></span>;
  const icon = phoneApps.find((a) => a.id === app)!;
  if (app === "calendar") {
    const now = new Date();
    return <span className="phone-app-icon phone-live-calendar"><b>{now.toLocaleDateString("en-US", { timeZone: "Europe/Berlin", weekday: "short" })}</b><strong>{now.toLocaleDateString("de-DE", { timeZone: "Europe/Berlin", day: "numeric" })}</strong></span>;
  }
  // Reuse the user's original artwork as a CSS sprite, without raster edits.
  return <span className={`phone-app-icon phone-icon-${app}`} style={{ "--sprite-x": `${-icon.x / 144 * 100}%`, "--sprite-y": `${-icon.y / 144 * 100}%`,
    backgroundPosition: `${icon.x / (1086 - 144) * 100}% ${icon.y / (1448 - 144) * 100}%` } as CSSProperties} />;
}
function Calendar({ offset, date }: { offset: number; date: Date }) {
  const berlin = new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Berlin", year: "numeric", month: "2-digit", day: "2-digit" }).formatToParts(date);
  const value = (key: string) => Number(berlin.find((p) => p.type === key)?.value);
  const month = new Date(value("year"), value("month") - 1 + offset, 1);
  const start = (month.getDay() + 6) % 7, count = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
  return <><div className="phone-month">‹ {month.toLocaleDateString("de-DE", { month: "long", year: "numeric" })} ›</div>
    <div className="phone-calendar">{["M", "D", "M", "D", "F", "S", "S"].map((day, i) => <b key={`d${i}`}>{day}</b>)}
      {Array.from({ length: start + count }, (_, i) => <span key={i} className={offset === 0 && i - start + 1 === value("day") ? "today" : ""}>{i >= start ? i - start + 1 : ""}</span>)}</div>
    <small>← → Monat wechseln</small></>;
}
function AppContent({ state: s, date }: { state: PhoneState; date: Date }) {
  if (s.app === "calendar") return <Calendar offset={s.month} date={date} />;
  if (s.app === "settings") return <div className="phone-list">
    <div className={s.row === 0 && s.nav === null ? "selected" : ""}>Tastentöne <strong>{s.settings.sound ? "An" : "Aus"}</strong></div>
    <div className={s.row === 1 && s.nav === null ? "selected" : ""}>Helligkeit <strong>‹ {s.settings.brightness}% ›</strong></div>
    <small>← → ändern · Enter bestätigen</small></div>;
  return null;
}
export function Phone() {
  const preview = isBrowser() && new URLSearchParams(location.search).get("view") === "phone";
  const [data, setData] = useState<PhonePayload>({ available: preview, open: preview, session: "preview", toggleKey: "UP" });
  const [state, setState] = useState(initialPhone);
  const [date, setDate] = useState(() => new Date());
  const [destination, setDestination] = useState<{ app: PhoneApp; number?: string } | null>(null);
  useEffect(() => { if (state.page !== "app") setDestination(null); }, [state.page]);
  const launch = (app: PhoneApp, number?: string) => {
    setDestination({ app, number });
    setState((s) => ({ ...s, app, page: "app", row: 0, nav: null, selected: phoneApps.findIndex((a) => a.id === app), recent: [app, ...s.recent.filter((a) => a !== app)] }));
  };
  const workspace = useRef<PhoneWorkspaceHandle>(null);
  const media = usePhoneMedia(data.session,data.open,data.available,preview,state.page==="app"&&state.app==="camera");
  useEffect(()=>{if(data.open&&state.page==="app"&&state.app==="messages")media.setHasMessage(false);},[data.open,state.page,state.app,media.notice]);
  useEffect(()=>{
    if(data.open&&media.call)setState((s)=>({...s,page:"app",app:"calls",selected:0,nav:null,row:0,recent:["calls",...s.recent.filter((a)=>a!=="calls")]}));
  },[media.call&&media.call.id,data.open]);
  useEffect(()=>{
    const c=media.call;
    const video=c&&c.members.some((m)=>m.id===c.self&&m.joined&&m.video);
    if((state.page!=="app"||state.app!=="camera")&&!video)media.setMode("off");
  },[state.page,state.app,media.call]);
  const ref = useRef({ data, state }); ref.current = { data, state };
  const closing = useRef(false), lastKey = useRef(0);
  const body = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const handler = (event: MessageEvent<unknown>) => {
      if (!isNuiMessage(event.data) || event.data.action !== "ui:phone") return;
      const payload = event.data.data;
      setData(payload || { available: false, open: false, session: "", toggleKey: "UP" });
      if (!payload || !payload.available) setState(initialPhone());
    };
    window.addEventListener("message", handler);
    const timer = window.setInterval(() => setDate(new Date()), 1000);
    return () => { window.removeEventListener("message", handler); window.clearInterval(timer); };
  }, []);
  useEffect(() => {
    body.current?.querySelector(".selected")?.scrollIntoView({ block: "nearest" });
  }, [state.row, state.page]);
  useEffect(() => {
    const close = async (session: string) => {
      if (closing.current) return;
      closing.current = true;
      try {
        if (preview) setData((v) => ({ ...v, open: false }));
        else await fetchNui("rp_phone:close", { session });
      } finally { closing.current = false; }
    };
    const handler = (event: KeyboardEvent) => {
      const { data: d, state: s } = ref.current;
      if (!d.available || event.metaKey || ((event.ctrlKey || event.altKey) && event.key !== "\\")) return;
      if (!d.open) {
        if (preview && event.key === "ArrowUp" && !event.repeat) { event.preventDefault(); setData({ ...d, open: true }); }
        return;
      }
      // The form owns navigation even when its focused element was replaced or
      // blurred by an error. Its own handler also handles Esc/cancel while busy.
      if (body.current?.querySelector(".phone-form")) return;
      const keys: Record<string, PhoneKey> = { ArrowUp: "up", ArrowDown: "down", ArrowLeft: "left", ArrowRight: "right", Enter: "enter", Backspace: "back", "\\": "back", Escape: "back" };
      const key = keys[event.key];
      const toggle = d.toggleKey !== "UP" && inputKey(event) === d.toggleKey;
      if (!key && !toggle) return; // WASD/camera continue through FiveM keep-input.
      event.preventDefault(); event.stopImmediatePropagation();
      const now = performance.now();
      if ((event.repeat && (key === "enter" || key === "back" || toggle)) || now - lastKey.current < 110) return;
      lastKey.current = now;
      if (toggle) { void close(d.session).catch(() => undefined); return; }
      if(s.page==="app"&&s.nav===null&&workspace.current?.key(key)){
        if(!preview)void fetchNui("rp_phone:key",{session:d.session,key,sound:s.settings.sound}).catch(()=>undefined);
        return;
      }
      const result = phoneStep(s, key);
      setState(result.state);
      if (result.close) void close(d.session).catch(() => undefined);
      else if (!preview) void fetchNui("rp_phone:key", { session: d.session, key, sound: s.settings.sound }).catch(() => undefined);
    };
    window.addEventListener("keydown", handler, true);
    return () => window.removeEventListener("keydown", handler, true);
  }, [preview]);
  const selected = state.nav === null && state.page === "home" ? phoneApps[state.selected].label
    : state.page === "recent" ? "Recent Apps" : state.page === "app" ? appLabel(state.app) : "iFruit";
  const time = date.toLocaleTimeString("de-DE", { timeZone: "Europe/Berlin", hour: "2-digit", minute: "2-digit" });
  const weekday = date.toLocaleDateString("de-DE", { timeZone: "Europe/Berlin", weekday: "short" });
  return <aside className={`phone-device ${data.available ? "available" : "unavailable"} ${data.open ? "expanded" : "peek"}`}
    aria-label="iFruit Handy" aria-hidden={!data.available} data-open={data.open} data-page={state.page} style={{ "--phone-brightness": state.settings.brightness / 100 } as CSSProperties}>
    <img className="phone-shell" src="./phone/mockup.png" alt="" draggable={false} />
    <header className="phone-status"><time>{time}</time><span className="phone-brand"><Fruit />{media.call ? "Anruf" : media.hasMessage ? "Nachricht" : "iFruit"}</span><span className="phone-status-right"><svg className="phone-signal" viewBox="0 0 22 18" aria-label="Signal"><path fill="currentColor" d="M0 13h4v5H0zm6-4h4v9H6zm6-4h4v13h-4zm6-5h4v18h-4z" /></svg>{weekday}<i className="phone-battery" /></span></header>
    <div className={`phone-screen ${state.page === "app" && ["calls", "contacts", "messages", "gallery", "ifruit"].includes(state.app) ? "phone-communication-screen" : ""} ${state.page === "app" && state.app === "ifruit" ? "phone-social-screen" : ""} ${state.page === "app" && state.app === "camera" ? "phone-camera-screen" : ""}`}>
      <h2 className="phone-app-title" aria-live="polite">{selected}</h2>
      {state.page === "home" ? <div className="phone-app-grid" role="grid" aria-label="Apps">{phoneApps.map((app, index) =>
        <div role="gridcell" key={app.id} aria-selected={state.selected === index && state.nav === null} className={`phone-app ${state.selected === index && state.nav === null ? "selected" : ""}`}>
          <AppIcon app={app.id} />{app.id==="messages"&&media.hasMessage&&<i className="phone-new-message" aria-label="Neue Nachricht"/>}<span>{app.label}</span></div>)}<span className="phone-page-dot" /></div>
        : <div className="phone-app-content" ref={body} key={state.page === "recent" ? "recent" : state.app}>
          {state.page === "recent" ? state.recent.length ? state.recent.map((app, i) => <div className="phone-recent" key={app}>
            <div className={state.row === i * 2 && state.nav === null ? "selected" : ""}><AppIcon app={app} /><span>{appLabel(app)}</span><small>Öffnen ↵</small></div>
            <div className={`phone-dismiss ${state.row === i * 2 + 1 && state.nav === null ? "selected" : ""}`}>App schließen <span>×</span></div>
          </div>) : <div className="phone-empty"><h3>Alles geschlossen.</h3><p>Hier findest du zuletzt geöffnete Apps.</p></div>
            : state.app==="calendar"||state.app==="settings" ? <AppContent state={state} date={date} />
            : state.app==="camera" ? <PhoneCamera key={`${data.session}:camera`} ref={workspace} session={data.session} preview={preview} focused={data.open&&state.nav===null} open={data.open} media={media} launch={launch}/>
            : state.app==="gallery" ? <PhoneGallery key={`${data.session}:gallery`} ref={workspace} session={data.session} preview={preview} focused={data.open&&state.nav===null} open={data.open} launch={launch}/>
            : state.app==="ifruit" ? <PhoneSocial key={`${data.session}:social`} ref={workspace} session={data.session} preview={preview} focused={data.open&&state.nav===null} open={data.open} launch={launch}/>
            : state.app==="calls"||state.app==="contacts"||state.app==="messages" ? <PhoneCommunication
                key={`${data.session}:${state.app}:${destination?.app === state.app ? destination.number ?? "" : ""}`}
                ref={workspace} app={state.app} session={data.session} preview={preview} focused={data.open && state.nav===null} open={data.open} media={media}
                initialNumber={destination?.app === state.app ? destination.number : undefined} launch={launch} />
            : <PhoneWorkspace key={`${data.session}:${state.app}`} ref={workspace} app={state.app} session={data.session} preview={preview} open={data.open} focused={state.nav===null} media={media}
                launch={launch} />}
        </div>}
    </div>
    <nav className="phone-navigation" aria-label="Handy Navigation">{["Zuletzt geöffnete Apps", "Home", "Zurück"].map((label, i) =>
      <div key={label} role="button" aria-label={label} aria-pressed={state.nav === i} className={state.nav === i ? "selected" : ""}>
        {i === 0 ? <span className="phone-recents-symbol">☰</span> : i === 1 ? <Fruit /> : <svg className="phone-back-symbol" viewBox="0 0 40 35" aria-hidden="true"><path d="M15 7H6l8-6M6 7l8 7M9 7h14c16 0 16 24 0 24H8" fill="none" stroke="currentColor" strokeWidth="5" strokeLinejoin="round" /></svg>}
      </div>)}</nav>
  </aside>;
}
