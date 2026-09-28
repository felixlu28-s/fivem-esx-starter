import { forwardRef, useEffect, useImperativeHandle, useRef, useState, type CSSProperties, type ReactNode } from "react";
import { UiIcon, type UiIconName } from "../components/UiIcon";
import { PhoneForm, type PhoneField, type PhoneFormState } from "../components/PhoneForm";
import { PhoneVideo } from "../components/PhoneVideo";
import { phoneRequest } from "../lib/phoneRequest";
import type { PhoneApp, PhoneKey } from "../lib/phone";
import type { Contact, PhoneConversation, PhoneHistory, PhoneMessage, PhoneProfile } from "../lib/phoneData";
import type { PhoneMedia } from "../lib/usePhoneMedia";
import type { PhoneWorkspaceHandle } from "./PhoneWorkspace";
import "../phone-communication.css";

type Props = {
  app: "calls" | "contacts" | "messages"; session: string; preview: boolean; focused: boolean;
  open: boolean; initialNumber?: string; media: PhoneMedia; launch: (app: PhoneApp, number?: string) => void;
};
type Screen = { kind: "root" } | { kind: "contact"; number: string; id?: string } | { kind: "thread"; number: string };
type Tab = "history" | "contacts" | "keypad";
type Action = { id: string; label: string; run: () => void; content?: ReactNode; className?: string; disabled?: boolean };
const numberValid = (number: string) => /^555\d{7}$/.test(number);
const field = (key: string, label: string, value = "", max = 60, multiline = false): PhoneField => ({ key, label, value, max, multiline, telephone: key === "number" });
const stamp = (created: number) => new Date(created * 1000).toLocaleString("de-DE", { timeZone: "Europe/Berlin", day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" });
const shortDate = (created: number) => {
  const date = new Date(created * 1000), now = new Date();
  const sameDay = date.toLocaleDateString("de-DE", { timeZone: "Europe/Berlin" }) === now.toLocaleDateString("de-DE", { timeZone: "Europe/Berlin" });
  return date.toLocaleString("de-DE", sameDay ? { timeZone: "Europe/Berlin", hour: "2-digit", minute: "2-digit" } : { timeZone: "Europe/Berlin", day: "2-digit", month: "2-digit" });
};
const failure: Record<string, string> = {
  unknown_number: "Diese Nummer ist nicht vergeben.", number_unavailable: "Zurzeit nicht erreichbar oder bereits im Gespräch.",
  limit: "Die maximale Anzahl ist erreicht.", rate_limited: "Bitte einen Moment warten.",
  invalid_fields: "Bitte prüfe deine Eingaben.", invalid_state: "Öffne das Handy bitte erneut.",
  voice_conflict: "Die Voice-Resource benötigt einen Telefonadapter.", unavailable: "Der Telefondienst ist momentan nicht erreichbar.",
};
function Avatar({ name, large = false }: { name: string; large?: boolean }) {
  const initials = name.trim().split(/\s+/).slice(0, 2).map((v) => v[0]).join("");
  return <span className={`comm-avatar ${large ? "large" : ""}`} aria-hidden="true">{/^\d/.test(name) ? <UiIcon name="person" /> : initials}</span>;
}
function Empty({ icon, title, text }: { icon: UiIconName; title: string; text: string }) {
  return <div className="phone-empty comm-empty"><UiIcon name={icon} /><p>{title}</p><small>{text}</small></div>;
}

/** Communication presentation only. Ownership, delivery and calls stay in rp_phone. */
export const PhoneCommunication = forwardRef<PhoneWorkspaceHandle, Props>(function PhoneCommunication({ app, session, preview, focused, open, initialNumber, media, launch }, ref) {
  const [profile, setProfile] = useState<PhoneProfile | null>(null);
  const [screen, setScreen] = useState<Screen>(initialNumber && app === "messages" ? { kind: "thread", number: initialNumber } : { kind: "root" });
  const [trail, setTrail] = useState<Screen[]>([]);
  const [tab, setTab] = useState<Tab>("keypad"), [selected, setSelected] = useState("");
  const [digits, setDigits] = useState(""), [query, setQuery] = useState(""), [missed, setMissed] = useState(false);
  const [history, setHistory] = useState<PhoneHistory[]>([]), [conversations, setConversations] = useState<PhoneConversation[]>([]);
  const [messages, setMessages] = useState<PhoneMessage[]>([]), [more, setMore] = useState(false), [before, setBefore] = useState<number>();
  const [form, setForm] = useState<PhoneFormState | null>(null), [busy, setBusy] = useState(false), [error, setError] = useState("");
  const [reload, setReload] = useState(0), [seconds, setSeconds] = useState(0);
  const root = useRef<HTMLDivElement>(null), alive = useRef(true), busyRef = useRef(false);
  const call = media.call, me = call ? call.members.find((member) => member.id === call.self) : undefined;
  const connected = !!(call && me?.joined && call.members.filter((member) => member.joined).length > 1);
  const contacts = [...(profile?.contacts ?? [])].sort((a, b) => a.name.localeCompare(b.name, "de", { sensitivity: "base" }));
  const contactFor = (number: string) => contacts.find((c) => c.number === number);
  const nameFor = (number: string) => contactFor(number)?.name ?? number;
  const request = async (action: string, data: Record<string, unknown> = {}) => {
    const result = await phoneRequest(session, preview, action, data);
    if (!result.ok) throw new Error(failure[result.error ?? ""] ?? "Diese Aktion ist gerade nicht möglich.");
    if (alive.current && result.phone?.kind === "home") setProfile(result.phone.profile);
    return result.phone;
  };
  const run = (work: () => Promise<void>) => {
    if (busyRef.current) return;
    busyRef.current = true; setBusy(true); setError("");
    void work().catch((e: unknown) => { if (alive.current) setError(e instanceof Error ? e.message : "Verbindung fehlgeschlagen."); })
      .finally(() => { busyRef.current = false; if (alive.current) setBusy(false); });
  };
  const go = (next: Screen) => {
    setTrail((previous) => next.kind === "root" ? [] : screen.kind === next.kind ? previous : [...previous, screen]);
    setScreen(next); setBefore(undefined); setMore(false); setError(""); setSelected(next.kind === "thread" ? "reply" : "");
  };
  const back = () => {
    const previous = trail[trail.length - 1] ?? { kind: "root" };
    setTrail((value) => value.slice(0, -1)); setScreen(previous); setBefore(undefined); setMore(false); setSelected(previous.kind === "thread" ? "reply" : "");
  };
  const edit = (title: string, fields: PhoneField[], save: PhoneFormState["save"], submitLabel?: string) => setForm({ title, fields, save, submitLabel, nonce: crypto.randomUUID() });
  const dial = async (number: string, video = false) => {
    if (!numberValid(number)) throw new Error("Die Nummer beginnt mit 555 und hat zehn Ziffern.");
    await request("call_start", { number, video });
  };
  const contactForm = (contact?: Contact, number = "") => edit(contact ? "Kontakt bearbeiten" : "Neuer Kontakt", [field("name", "Name", contact?.name), field("number", "Nummer", contact?.number ?? number, 16)], async (values, nonce) => {
    if (!values.name.trim() || !numberValid(values.number)) throw new Error("Bitte Name und eine gültige Telefonnummer eingeben.");
    await request("contact", { id: contact?.id ?? nonce, name: values.name.trim(), number: values.number });
    go({ kind: "contact", number: values.number, id: contact?.id ?? nonce });
  });
  const compose = (number?: string) => edit(number ? "Nachricht schreiben" : "Neue Nachricht", [
    ...(!number ? [field("number", "An", "", 16)] : []), field("body", "Nachricht", "", 1000, true),
  ], async (values, nonce) => {
    const recipient = number ?? values.number;
    if (!numberValid(recipient) || !values.body.trim()) throw new Error("Bitte Empfänger und Nachricht eingeben.");
    await request("send", { number: recipient, body: values.body.trim(), nonce });
    go({ kind: "thread", number: recipient }); setReload((n) => n + 1);
  }, "Senden");

  useEffect(() => { alive.current = true; return () => { alive.current = false; }; }, []);
  useEffect(() => { run(async () => { await request("home"); }); }, []);
  useEffect(() => {
    if (!open || form) return;
    let cancelled = false, timer = 0;
    const load = () => {
      if (cancelled) return;
      if (busyRef.current) { timer = window.setTimeout(load, 100); return; }
      run(async () => {
        if (app === "calls" && !call && screen.kind === "root" && tab === "history") {
          const reply = await request("history"); if (!cancelled && reply?.kind === "history") setHistory(reply.rows);
        }
        if (app === "messages" && screen.kind !== "contact") {
          if (screen.kind === "thread") {
            const reply = await request("messages", { number: screen.number, before });
            if (cancelled || reply?.kind !== "messages") return;
            setMessages(reply.rows); setMore(reply.more);
            // Only a visibly opened thread marks received messages as read.
            if (reply.rows.length) {
              await request("read", { number: screen.number, last: reply.rows[0].id });
              if (!cancelled) setMessages(reply.rows.map((m) => m.mine ? m : { ...m, seen: true }));
            }
          } else {
            const reply = await request("conversations", { before });
            if (!cancelled && reply?.kind === "conversations") { setConversations(reply.rows); setMore(reply.more); }
          }
        }
      });
    };
    load(); return () => { cancelled = true; window.clearTimeout(timer); };
  }, [app, screen, tab, before, reload, media.notice, !!call, open, !!form]);
  useEffect(() => {
    setSeconds(0);
    if (!connected) return;
    const started = Date.now(), timer = window.setInterval(() => setSeconds(Math.floor((Date.now() - started) / 1000)), 1000);
    return () => window.clearInterval(timer);
  }, [call && call.id, connected]);
  useEffect(() => {
    if (screen.kind === "thread" && selected === "reply" && !before) {
      const chat = root.current?.querySelector<HTMLElement>(".comm-chat");
      if (chat) chat.scrollTop = chat.scrollHeight;
    }
    const element = root.current?.querySelector<HTMLElement>(".comm-control.selected");
    const scroll = element?.closest<HTMLElement>(".comm-scroll");
    if (!element || !scroll) return;
    const bounds = element.getBoundingClientRect(), area = scroll.getBoundingClientRect();
    if (bounds.top < area.top) scroll.scrollTop -= area.top - bounds.top;
    else if (bounds.bottom > area.bottom) scroll.scrollTop += bounds.bottom - area.bottom;
  }, [selected, screen, tab, messages, conversations, profile, focused, before]);

  // Spatial keyboard rows also describe the visual layout, including dial pad and app tabs.
  const navigation: Action[][] = [];
  const group = (items: Action[], className = "", key?: string) => {
    if (!items.length) return null;
    navigation.push(items);
    const highlighted = selected || navigation[0]?.[0]?.id;
    return <div className={`comm-controls ${className}`} key={key} style={{ "--comm-columns": items.length } as CSSProperties}>
      {items.map((action) => <div key={action.id} role="button" tabIndex={-1} aria-label={action.label} aria-disabled={action.disabled || busy}
        aria-pressed={!form && focused && action.id === highlighted}
        data-phone-action={action.id} className={`comm-control ${action.className ?? ""} ${!form && focused && action.id === highlighted ? "selected" : ""}`}>
        {action.content ?? <span>{action.label}</span>}
      </div>)}
    </div>;
  };
  const iconAction = (id: string, label: string, icon: UiIconName, run: () => void, className = ""): Action => ({ id, label, run, className,
    content: <><UiIcon name={icon} /><span>{label}</span></> });
  const tools = (title: string, actions: Action[], subtitle?: string) => <header className="comm-heading"><div><h3>{title}</h3>{subtitle && <small>{subtitle}</small>}</div>{group(actions, "comm-tools")}</header>;
  const search = (label: string) => group([{ id: "search", label, run: () => edit(label, [field("query", "Name oder Nummer", query)], async (v) => { setQuery(v.query.trim()); }),
    content: <><UiIcon name="search" /><span>{query || "Suchen"}</span>{query && <small>Ändern</small>}</>, className: "comm-search" }]);
  const showContact = (number: string, id?: string) => go({ kind: "contact", number, id });
  const contactList = () => {
    const filtered = contacts.filter((c) => `${c.name} ${c.number}`.toLocaleLowerCase("de").includes(query.toLocaleLowerCase("de")));
    let letter = "";
    return <>
      {tools("Kontakte", [iconAction("new", "Kontakt hinzufügen", "plus", () => contactForm())])}
      {search("Kontakt suchen")}
      <div className="comm-scroll">
        <div className="comm-my-card"><Avatar name={profile?.name ?? "Du"} /><div><strong>{profile?.name ?? "Meine Karte"}</strong><small>Meine Nummer · {profile?.number ?? "…"}</small></div></div>
        {filtered.map((contact) => {
          const first = contact.name[0]?.toLocaleUpperCase("de") ?? "#", heading = first !== letter; letter = first;
          return <section key={contact.id}>{heading && <h4 className="comm-letter">{first}</h4>}{group([{ id: `contact:${contact.id}`, label: contact.name, run: () => showContact(contact.number, contact.id),
            className: "comm-list-item", content: <><Avatar name={contact.name} /><span><strong>{contact.name}</strong><small>Mobil</small></span><b className="comm-chevron">›</b></> }])}</section>;
        })}
        {!filtered.length && <Empty icon="person" title={contacts.length ? "Keine Treffer" : "Noch keine Kontakte."} text={contacts.length ? "Versuche einen anderen Namen oder eine Nummer." : "Mit + legst du deinen ersten Kontakt an."} />}
      </div>
    </>;
  };

  let body: ReactNode, tabs: ReactNode = null;
  if (app === "calls" && call && me) {
    const others = call.members.filter((member) => member.id !== call.self);
    const title = others.length === 1 ? nameFor(others[0].number) === others[0].number ? others[0].name : nameFor(others[0].number) : "Konferenz";
    const status = !me.joined ? "Eingehender Anruf" : !connected ? "Wird angerufen …" : `${Math.floor(seconds / 60).toString().padStart(2, "0")}:${(seconds % 60).toString().padStart(2, "0")}`;
    body = <div className="comm-live-call comm-scroll">
      <div className="phone-call-title"><Avatar name={title} large /><h3>{title}</h3><small>{status}</small>{others.length > 1 && <small>{call.members.length} Teilnehmer</small>}</div>
      <div className="phone-call-members">{call.members.map((member) => <div key={member.id}><span>{member.id === call.self ? "Du" : nameFor(member.number) === member.number ? member.name : nameFor(member.number)}</span><small>{!member.joined ? "Klingelt …" : member.muted ? "Mikro aus" : "Verbunden"}</small></div>)}</div>
      <div className="phone-videos">{me.video && media.capture && <PhoneVideo stream={media.capture.video()} label="Du" />}{others.filter((m) => m.joined && m.video).map((m) => <PhoneVideo key={m.id} stream={media.streams[m.id]} label={m.name} />)}</div>
      {me.joined ? group([
        iconAction("mute", me.muted ? "Mikrofon einschalten" : "Mikrofon stummschalten", me.muted ? "micOff" : "microphone", () => run(async () => { await request("call_state", { call: call.id, muted: !me.muted, video: me.video }); }), me.muted ? "enabled" : ""),
        iconAction("video", me.video ? "Kamera ausschalten" : "Kamera einschalten", "video", () => run(async () => { await request("call_state", { call: call.id, muted: me.muted, video: !me.video }); }), me.video ? "enabled" : ""),
        ...(call.host === call.self ? [iconAction("invite", "Teilnehmer hinzufügen", "plus", () => edit("Zur Konferenz einladen", [field("number", "Telefonnummer", "", 16)], async (values) => {
          if (!numberValid(values.number)) throw new Error("Bitte eine gültige Telefonnummer eingeben."); await request("call_invite", { call: call.id, number: values.number });
        }, "Einladen"))] : []),
      ], "comm-call-actions") : group([
        iconAction("accept", "Annehmen · Audio", "call", () => run(async () => { await request("call_accept", { call: call.id, video: false }); }), "comm-green"),
        ...(call.video ? [iconAction("accept-video", "Mit Video annehmen", "video", () => run(async () => { await request("call_accept", { call: call.id, video: true }); }), "comm-green")] : []),
      ], "comm-call-actions")}
      {group([iconAction("hangup", me.joined ? "Auflegen" : "Ablehnen", "call", () => run(async () => { await request("call_leave", { call: call.id }); }), "comm-hangup")], "comm-hangup-row")}
    </div>;
  } else if (screen.kind === "contact") {
    const contact = screen.id ? contacts.find((entry) => entry.id === screen.id) : contactFor(screen.number), number = screen.number, name = contact?.name ?? number;
    body = <>
      {tools("", [iconAction("back", "Zurück", "back", back), iconAction("edit", contact ? "Kontakt bearbeiten" : "Kontakt speichern", "compose", () => contactForm(contact, number))])}
      <div className="comm-scroll"><div className="comm-person"><Avatar name={name} large /><h3>{name}</h3><small>{number}</small></div>
        {group([
          iconAction("message", "Nachricht schreiben", "message", () => { if (app === "messages") { go({ kind: "thread", number }); setTrail([]); } else launch("messages", number); }),
          iconAction("voice", "Anrufen", "call", () => run(() => dial(number))),
          iconAction("video", "Videoanruf", "video", () => run(() => dial(number, true))),
        ], "comm-contact-actions")}
        {group([{ id: "number", label: `Mobil ${number} anrufen`, run: () => run(() => dial(number)), className: "comm-number-card", content: <><small>Mobil</small><span>{number}</span><UiIcon name="call" /></> }])}
        {contact && group([{ id: "delete", label: "Kontakt löschen", className: "comm-danger comm-text-action", run: () => edit("Kontakt wirklich löschen?", [], async () => { await request("contact", { id: contact.id, delete: true }); go({ kind: "root" }); }, "Löschen") }])}
      </div>
    </>;
  } else if (app === "contacts" || (app === "calls" && tab === "contacts")) {
    body = contactList();
  } else if (app === "calls" && tab === "keypad") {
    const values = [["1", ""], ["2", "ABC"], ["3", "DEF"], ["4", "GHI"], ["5", "JKL"], ["6", "MNO"], ["7", "PQRS"], ["8", "TUV"], ["9", "WXYZ"], ["*", ""], ["0", "+"], ["#", ""]];
    body = <>
      {tools("Telefon", [], profile?.number ? `Meine Nummer: ${profile.number}` : "Verbinden …")}
      <div className="comm-dial-number">{group([{ id: "edit-number", label: "Nummer eingeben", run: () => edit("Nummer eingeben", [field("number", "Telefonnummer", digits, 16)], async (values) => { setDigits(values.number); setSelected("dial"); }),
        content: <><strong>{digits || "Nummer eingeben"}</strong><small>{digits && contactFor(digits)?.name || ""}</small></> }])}</div>
      <div className="comm-keypad">{[0, 1, 2, 3].map((row) => group(values.slice(row * 3, row * 3 + 3).map(([digit, letters]) => ({ id: `digit:${digit}`, label: digit,
        run: () => setDigits((v) => (v + digit).slice(0, 16)), className: "comm-digit", content: <><b>{digit}</b><small>{letters || "\u00a0"}</small></>,
      })), "comm-digit-row", String(row)))}</div>
      {group([
        iconAction("video", "Videoanruf starten", "video", () => run(() => dial(digits, true)), "comm-dial-secondary"),
        iconAction("dial", "Anrufen", "call", () => run(() => dial(digits)), "comm-dial-call"),
        iconAction("erase", "Letzte Ziffer löschen", "erase", () => setDigits((v) => v.slice(0, -1)), "comm-dial-secondary"),
      ], "comm-dial-actions")}
    </>;
  } else if (app === "calls") {
    const filtered = history.filter((entry) => !missed || entry.direction === "in" && entry.outcome === "missed");
    body = <>
      {tools("Anrufliste", [iconAction("refresh", "Verlauf aktualisieren", "refresh", () => setReload((v) => v + 1))])}
      {group([{ id: "all", label: "Alle", run: () => setMissed(false), className: !missed ? "active" : "" }, { id: "missed", label: "Verpasst", run: () => setMissed(true), className: missed ? "active" : "" }], "comm-segment")}
      <div className="comm-scroll">{filtered.map((entry) => {
        const missedCall = entry.direction === "in" && entry.outcome === "missed";
        const outcome = missedCall ? "Verpasst" : entry.outcome === "declined" ? "Abgelehnt" : entry.direction === "out" ? "Ausgehend" : "Eingehend";
        return group([{ id: `history:${entry.id}`, label: `${nameFor(entry.peer)} anrufen`, run: () => run(() => dial(entry.peer, !!entry.video)), className: `comm-list-item ${missedCall ? "comm-danger" : ""}`,
          content: <><UiIcon name={entry.video ? "video" : "call"} /><span><strong>{nameFor(entry.peer)}</strong><small>{outcome}{entry.video ? " · Video" : ""}</small></span><time>{shortDate(entry.created)}</time></> },
        { id: `info:${entry.id}`, label: `Kontaktinfo ${nameFor(entry.peer)}`, run: () => showContact(entry.peer), className: "comm-history-info", content: <span>i</span> }], "comm-history-row", String(entry.id));
      })}{!filtered.length && <Empty icon="clock" title={missed ? "Keine verpassten Anrufe" : "Noch keine Anrufe"} text="Deine ein- und ausgehenden Anrufe erscheinen hier." />}</div>
    </>;
  } else if (screen.kind === "thread") {
    const number = screen.number;
    body = <>
      <header className="comm-thread-header">{group([
        iconAction("back", "Zur Nachrichtenübersicht", "back", () => go({ kind: "root" })),
        { id: "person", label: `Kontaktinfo ${nameFor(number)}`, run: () => showContact(number), content: <><Avatar name={nameFor(number)} /><strong>{nameFor(number)}</strong></> },
        iconAction("voice", "Anrufen", "call", () => run(() => dial(number))),
      ])}</header>
      <div className="comm-scroll comm-chat" aria-label="Chatverlauf">
        {before && group([{ id: "latest", label: "Neueste Nachrichten", className: "comm-text-action", run: () => { setBefore(undefined); setSelected("reply"); } }])}
        {more && group([{ id: "older", label: "Ältere Nachrichten", className: "comm-text-action", run: () => { setBefore(messages[messages.length - 1]?.id); setSelected("latest"); } }])}
        {!messages.length && <Empty icon="message" title="Sag Hallo." text="Schreibe deine erste Nachricht an diesen Kontakt." />}
        {[...messages].reverse().map((message, index) => <section key={message.id}>
          {(index === 0 || messages[messages.length - index]?.created < message.created - 1800) && <time className="comm-chat-date">{stamp(message.created)}</time>}
          {group([{ id: `message:${message.id}`, label: `${message.mine ? "Du" : nameFor(number)}: ${message.body}`, run: () => undefined,
            className: `comm-bubble ${message.mine ? "mine" : ""}`, content: <><p>{message.body}</p><time>{new Date(message.created * 1000).toLocaleTimeString("de-DE", { timeZone: "Europe/Berlin", hour: "2-digit", minute: "2-digit" })}</time></> }], "comm-bubble-row")}
          {message.mine && index === messages.length - 1 && <small className="comm-read-state">{message.seen ? "Gelesen" : "Gesendet"}</small>}
        </section>)}
      </div>
      {group([{ id: "reply", label: "Nachricht schreiben", run: () => compose(number), className: "comm-composer", content: <><span>Nachricht</span><UiIcon name="arrow" /></> }], "comm-composer-row")}
    </>;
  } else {
    const filtered = conversations.filter((c) => `${nameFor(c.number)} ${c.number}`.toLocaleLowerCase("de").includes(query.toLocaleLowerCase("de")));
    body = <>
      {tools("Nachrichten", [iconAction("compose", "Neue Nachricht", "compose", () => compose())])}
      {search("Gespräch suchen")}
      <div className="comm-scroll">{filtered.map((conversation) => group([{ id: `thread:${conversation.number}`, label: nameFor(conversation.number), run: () => { setMessages([]); go({ kind: "thread", number: conversation.number }); }, className: "comm-list-item comm-thread-row",
        content: <><span className={`comm-unread ${conversation.unread ? "on" : ""}`} /><Avatar name={nameFor(conversation.number)} /><span><strong>{nameFor(conversation.number)}</strong><small>{conversation.mine ? "Du: " : ""}{conversation.body}</small></span><aside><time>{shortDate(conversation.created)}</time><b className="comm-chevron">›</b></aside></> }], "", conversation.number))}
        {!filtered.length && <Empty icon="message" title={query ? "Keine Treffer" : "Noch keine Nachrichten."} text="Beginne ein Gespräch oder schreibe einem deiner Kontakte." />}
        {before && group([{ id: "latest", label: "Neueste Gespräche", className: "comm-text-action", run: () => { setBefore(undefined); setSelected(""); } }])}
        {more && group([{ id: "older", label: "Weitere Gespräche", className: "comm-text-action", run: () => { setBefore(conversations[conversations.length - 1]?.id); setSelected(""); } }])}
      </div>
    </>;
  }
  if (app === "calls" && !call) tabs = group(([["history", "Anrufliste", "clock"], ["contacts", "Kontakte", "person"], ["keypad", "Ziffernblock", "dialpad"]] as const).map(([id, label, icon]) => ({
    ...iconAction(`tab:${id}`, label, icon, () => { setTab(id); go({ kind: "root" }); setQuery(""); }), className: tab === id ? "active" : "",
  })), "comm-tabs");

  const available = navigation.flat(), current = available.find((action) => action.id === selected) ?? available[0];
  useEffect(() => {
    if (current && selected !== current.id) setSelected(current.id);
  }, [current?.id, selected]);
  useImperativeHandle(ref, () => ({ key: (key: PhoneKey) => {
    if (form) return true;
    if (key === "back") { if (screen.kind !== "root") { back(); return true; } return false; }
    if (key === "enter") { if (current && !current.disabled && !busyRef.current) current.run(); return true; }
    const row = Math.max(0, navigation.findIndex((items) => items.some((action) => action.id === current?.id)));
    const column = Math.max(0, navigation[row]?.findIndex((action) => action.id === current?.id) ?? 0);
    if (key === "down" && row === navigation.length - 1) return false;
    const nextRow = Math.max(0, Math.min(navigation.length - 1, row + (key === "down" ? 1 : key === "up" ? -1 : 0)));
    const nextColumn = Math.max(0, Math.min((navigation[nextRow]?.length ?? 1) - 1, column + (key === "right" ? 1 : key === "left" ? -1 : 0)));
    setSelected(navigation[nextRow]?.[nextColumn]?.id ?? ""); return true;
  } }));
  const submit = () => { if (form) run(async () => { await form.save(Object.fromEntries(form.fields.map((f) => [f.key, f.value])), form.nonce); if (alive.current) setForm((current) => current?.nonce === form.nonce ? null : current); }); };
  return <div ref={root} className={`phone-communication ${call && app === "calls" ? "in-call" : ""}`} data-app={app} data-screen={screen.kind} data-tab={app === "calls" ? tab : undefined}>
    {(error || media.error) && <div className="phone-app-error" role="status">{error || media.error}</div>}
    {form ? <PhoneForm form={form} setForm={setForm} busy={busy} submit={submit} session={session} preview={preview} active={open} /> : <>{body}{tabs}</>}
  </div>;
});
