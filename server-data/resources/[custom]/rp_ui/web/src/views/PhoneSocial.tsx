import { forwardRef, useEffect, useImperativeHandle, useRef, useState, type CSSProperties, type ReactNode } from "react";
import { UiIcon, type UiIconName } from "../components/UiIcon";
import { PhoneForm, type PhoneField, type PhoneFormState } from "../components/PhoneForm";
import { phoneRequest } from "../lib/phoneRequest";
import { useGalleryScope } from "../lib/useGalleryScope";
import { listLocalMedia, loadLocalMedia, type GalleryItem } from "../lib/phoneGallery";
import { forPublication } from "../lib/phonePublication";
import type { PhoneApp } from "../lib/phone";
import type { PhoneComment, PhonePost, SocialAccount, SocialIdentity, SocialProfile } from "../lib/phoneData";
import type { PhoneWorkspaceHandle } from "./PhoneWorkspace";
import "../phone-communication.css";
import "../phone-social.css";

type Props = { session: string; preview: boolean; focused: boolean; open: boolean; launch: (app: PhoneApp) => void };
type Screen = { kind: "feed"; following: boolean } | { kind: "profile"; id: number } | { kind: "post" | "comments"; post: PhonePost }
  | { kind: "accounts" | "compose" } | { kind: "search"; query: string }
  | { kind: "people"; id: number; mode: "followers" | "following" };
type Action = { id: string; label: string; content: ReactNode; run: () => void; className?: string };
const field = (key: string, label: string, value = "", max = 60, multiline = false): PhoneField => ({ key, label, value, max, multiline });
const date = (created: number) => new Date(created * 1000).toLocaleString("de-DE", { timeZone: "Europe/Berlin", day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });
const errors: Record<string, string> = {
  social_register: "Erstelle zuerst dein iFruit-Profil.", social_limit: "Alle freigeschalteten Profile sind bereits angelegt.",
  social_changed: "Das aktive Profil hat sich geändert. Öffne iFruit erneut.", handle_taken: "Dieser Benutzername ist schon vergeben.",
  invalid_fields: "Prüfe deine Eingaben. Benutzername: 3–24 Zeichen, beginnt mit einem Buchstaben; a–z, Zahlen, Punkt und Unterstrich.",
  limit: "Dein Profil hat die maximale Anzahl an Fotobeiträgen erreicht.", busy: "Bitte einen Moment warten.",
  rate_limited: "Bitte kurz warten und erneut versuchen.", invalid_state: "Öffne das Handy bitte erneut.",
  not_found: "Dieser Inhalt ist nicht mehr verfügbar.", conflict: "Diese Anfrage wurde bereits mit anderen Daten verarbeitet.",
};
function Avatar({ name, large = false }: { name: string; large?: boolean }) {
  return <span className={`social-avatar ${large ? "large" : ""}`} aria-hidden="true">{name.trim().split(/\s+/).slice(0, 2).map((s) => s[0]).join("")}</span>;
}
function Empty({ icon, title, text }: { icon: UiIconName; title: string; text: string }) {
  return <div className="social-empty"><UiIcon name={icon} /><strong>{title}</strong><p>{text}</p></div>;
}
// Only load photos visible in the inner scroll area. No feed polling or broadcast images.
function Photo({ id, caption, session, preview, cache }: { id: number; caption: string; session: string; preview: boolean; cache: Map<number, string> }) {
  const [image, setImage] = useState(cache.get(id) ?? ""), [failed, setFailed] = useState(false);
  const root = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (cache.has(id)) { setImage(cache.get(id)!); return; }
    const element = root.current; if (!element) return;
    let cancelled = false, started = false;
    const observer = new IntersectionObserver((entries) => {
      if (started || !entries.some((entry) => entry.isIntersecting)) return;
      started = true; observer.disconnect();
      void phoneRequest(session, preview, "image", { id }).then((result) => {
        if (cancelled) return;
        if (!result.ok || result.phone?.kind !== "image") { setFailed(true); return; }
        cache.set(id, result.phone.image);
        if (cache.size > 36) cache.delete(cache.keys().next().value!);
        setImage(result.phone.image);
      }).catch(() => { if (!cancelled) setFailed(true); });
    }, { root: element.closest(".social-scroll"), rootMargin: "30px" });
    observer.observe(element);
    return () => { cancelled = true; observer.disconnect(); };
  }, [id, session, preview, cache]);
  return <div ref={root} className="social-photo">{image ? <img src={image} alt={caption || "iFruit-Foto"} draggable={false} /> : <span><UiIcon name="gallery" />{failed ? "Foto nicht verfügbar" : ""}</span>}</div>;
}

export const PhoneSocial = forwardRef<PhoneWorkspaceHandle, Props>(function PhoneSocial({ session, preview, focused, open, launch }, ref) {
  const [account, setAccount] = useState<SocialAccount | null>(null), [screen, setScreen] = useState<Screen>({ kind: "feed", following: false });
  const [trail, setTrail] = useState<Screen[]>([]), [selected, setSelected] = useState("");
  const [posts, setPosts] = useState<PhonePost[]>([]), [comments, setComments] = useState<PhoneComment[]>([]), [people, setPeople] = useState<SocialProfile[]>([]);
  const [profile, setProfile] = useState<SocialProfile | null>(null), [before, setBefore] = useState<number>(), [more, setMore] = useState(false);
  const [revision, setRevision] = useState(0), [busy, setBusy] = useState(false), [error, setError] = useState("");
  const [form, setForm] = useState<PhoneFormState | null>(null), [draftPhoto, setDraftPhoto] = useState("");
  const [photos, setPhotos] = useState<(GalleryItem & { url: string })[]>([]), [photoPage, setPhotoPage] = useState(0);
  const { scope, error: galleryError } = useGalleryScope(session, preview);
  const root = useRef<HTMLDivElement>(null), alive = useRef(true), busyRef = useRef(false), cache = useRef(new Map<number, string>());
  const actor = account?.active ?? 0, active = account?.profiles.find((p) => p.id === actor);
  const request = async (action: string, data: Record<string, unknown> = {}) => {
    const result = await phoneRequest(session, preview, action, { actor, ...data });
    if (!result.ok) throw new Error(errors[result.error ?? ""] ?? "iFruit ist gerade nicht erreichbar. Bitte erneut versuchen.");
    return result.phone;
  };
  const run = (work: () => Promise<void>) => {
    if (busyRef.current) return;
    busyRef.current = true; setBusy(true); setError("");
    void work().catch((e: unknown) => { if (alive.current) setError(e instanceof Error ? e.message : "Verbindung fehlgeschlagen."); })
      .finally(() => { busyRef.current = false; if (alive.current) setBusy(false); });
  };
  const home = async () => { const data = await request("social_home"); if (alive.current && data?.kind === "social_home") setAccount(data); };
  const go = (next: Screen, replace = false) => {
    setTrail((s) => replace ? [] : [...s, screen].slice(-12)); setScreen(next); setBefore(undefined); setMore(false); setSelected(""); setError("");
    setPosts([]); setComments([]); setPeople([]); setProfile(null);
  };
  const back = () => {
    if (trail.length) { const previous = trail[trail.length - 1]; setTrail((s) => s.slice(0, -1)); setScreen(previous); }
    else if (screen.kind !== "feed") setScreen({ kind: "feed", following: false });
    else return false;
    setPosts([]); setComments([]); setPeople([]); setProfile(null); setBefore(undefined); setSelected(""); setError(""); return true;
  };
  const edit = (title: string, fields: PhoneField[], save: PhoneFormState["save"], submitLabel = "Speichern") => {
    setError(""); setForm({ title, fields, save, submitLabel, nonce: crypto.randomUUID() });
  };
  const profileForm = (identity?: SocialIdentity) => edit(identity ? "Profil bearbeiten" : "Dein neues Profil", [
    field("handle", "Benutzername", identity?.handle, 24), field("name", "Anzeigename", identity?.name), field("bio", "Bio", identity?.bio, 160, true),
  ], async (values, nonce) => {
    const data = await request(identity ? "profile" : "social_create", { ...values, name: values.name.trim(), handle: values.handle.trim().toLowerCase(), nonce });
    if (!alive.current || data?.kind !== "social_home") return;
    setAccount(data); go({ kind: "profile", id: data.active }, true); setRevision((v) => v + 1);
  }, identity ? "Speichern" : "Profil erstellen");
  const follow = (id: number, enabled: boolean) => run(async () => {
    await request("follow", { id, enabled });
    if (!alive.current) return;
    setPosts((s) => s.map((p) => p.author === id ? { ...p, following: enabled } : p));
    setPeople((s) => s.map((p) => p.id === id ? { ...p, following: enabled, followers: Math.max(0, p.followers + (enabled ? 1 : -1)) } : p));
    setProfile((p) => p?.id === id ? { ...p, following: enabled, followers: Math.max(0, p.followers + (enabled ? 1 : -1)) } : p);
  });
  const like = (p: PhonePost) => run(async () => {
    await request("like", { id: p.id, enabled: !p.liked });
    if (!alive.current) return;
    const updated = { ...p, liked: !p.liked, likes: Math.max(0, p.likes + (p.liked ? -1 : 1)) };
    setPosts((s) => s.map((row) => row.id === p.id ? updated : row));
    setScreen((s) => s.kind === "post" && s.post.id === p.id ? { ...s, post: updated } : s);
  });
  const publish = (photo: GalleryItem & { url: string }) => {
    setDraftPhoto(photo.url);
    edit(`Neuer Beitrag · @${active?.handle}`, [field("caption", "Bildunterschrift", "", 1000, true)], async (values, nonce) => {
      const media = await loadLocalMedia(scope, photo.id);
      await request("publish_local", { image: await forPublication(media.blob), caption: values.caption, nonce });
      if (alive.current) { go({ kind: "profile", id: actor }, true); setRevision((v) => v + 1); }
    }, "Teilen");
  };
  useEffect(() => { alive.current = true; run(home); return () => { alive.current = false; }; }, []);
  useEffect(() => {
    if (!actor || !open || form) return;
    let cancelled = false, timer = 0;
    const load = () => {
      if (cancelled) return;
      if (busyRef.current) { timer = window.setTimeout(load, 100); return; }
      run(async () => {
        if (screen.kind === "accounts") { await home(); return; }
        if (screen.kind === "profile") {
          const data = await request("social_profile", { id: screen.id });
          if (cancelled) return;
          if (data?.kind === "social_profile") setProfile(data.profile);
        }
        if (screen.kind === "feed" || screen.kind === "profile" || screen.kind === "post") {
          const data = await request("feed", { before, following: screen.kind === "feed" && screen.following,
            author: screen.kind === "profile" ? screen.id : undefined, id: screen.kind === "post" ? screen.post.id : undefined });
          if (!cancelled && data?.kind === "feed") { setPosts(data.rows); setMore(data.more); }
        } else if (screen.kind === "comments") {
          const data = await request("comments", { id: screen.post.id, before });
          if (!cancelled && data?.kind === "comments") { setComments(data.rows); setMore(data.more === true); }
        } else if (screen.kind === "search" || screen.kind === "people") {
          const data = await request(screen.kind === "search" ? "social_search" : "social_people", { ...screen, before });
          if (!cancelled && data?.kind === "social_people") { setPeople(data.rows); setMore(data.more); }
        }
      });
    };
    load(); return () => { cancelled = true; window.clearTimeout(timer); };
  }, [screen, actor, before, revision, open, !!form]);
  useEffect(() => {
    if (screen.kind !== "compose" || !scope) return;
    let cancelled = false; const urls: string[] = [];
    void listLocalMedia(scope).then((data) => {
      if (!cancelled) setPhotos(data.items.filter((p) => p.kind === "photo").map((p) => {
        const url = URL.createObjectURL(p.thumbnail); urls.push(url); return { ...p, url };
      }));
    }).catch(() => { if (!cancelled) setError("Deine Galerie konnte nicht geöffnet werden."); });
    return () => { cancelled = true; urls.forEach((url) => URL.revokeObjectURL(url)); };
  }, [screen.kind, scope]);
  useEffect(() => {
    const element = root.current?.querySelector<HTMLElement>(".social-control.selected"), scroll = element?.closest<HTMLElement>(".social-scroll");
    if (!element || !scroll) return;
    const b = element.getBoundingClientRect(), area = scroll.getBoundingClientRect();
    if (b.top < area.top) scroll.scrollTop += b.top - area.top;
    else if (b.bottom > area.bottom) scroll.scrollTop += b.bottom - area.bottom;
  }, [selected, screen, focused, posts, people]);

  const groups: Action[][] = [];
  const controls = (actions: Action[], className = "") => {
    if (!actions.length) return null;
    groups.push(actions);
    return <div className={`comm-controls social-controls ${className}`} style={{ "--comm-columns": actions.length } as CSSProperties}>{actions.map((a) =>
      <div key={a.id} role="button" data-phone-action={a.id} aria-label={a.label} aria-pressed={focused && !form && (selected || groups[0]?.[0]?.id) === a.id}
        aria-disabled={busy} className={`social-control ${a.className ?? ""} ${focused && !form && (selected || groups[0]?.[0]?.id) === a.id ? "selected" : ""}`}>{a.content}</div>)}</div>;
  };
  const icon = (id: string, label: string, name: UiIconName, run: () => void, className = ""): Action => ({ id, label, run, className, content: <UiIcon name={name} /> });
  const photo = (p: PhonePost) => <Photo key={p.photo} id={p.photo} caption={p.caption} session={session} preview={preview} cache={cache.current} />;
  const pageControl = (last?: number) => <>{more && last && controls([{ id: "older", label: "Ältere Einträge", content: <span>Mehr laden <span aria-hidden="true">↓</span></span>, run: () => { setBefore(last); setSelected(""); } }], "social-more")}
    {before && controls([{ id: "latest", label: "Zurück zu den neuesten Einträgen", content: <span>Neueste Einträge</span>, run: () => { setBefore(undefined); setSelected(""); } }], "social-more")}</>;
  const renderPost = (p: PhonePost) => <article className="social-post" key={p.id}>
    {controls([{ id: `author:${p.id}`, label: `Profil @${p.handle}`, content: <><Avatar name={p.name} /><span><strong>{p.handle}</strong><small>Los Santos · {date(p.created)}</small></span></>, run: () => go({ kind: "profile", id: p.author }) },
      ...(p.author === actor ? [icon(`delete:${p.id}`, "Beitrag löschen", "trash", () => edit("Diesen Beitrag löschen?", [], async () => {
        await request("post_delete", { id: p.id }); if (alive.current) { go({ kind: "profile", id: actor }, true); setRevision((v) => v + 1); }
      }, "Löschen"))] : [])], "social-post-header")}
    {controls([{ id: `photo:${p.id}`, label: `Foto von @${p.handle}`, content: photo(p), run: () => go({ kind: "post", post: p }) }], "social-post-image")}
    {controls([icon(`like:${p.id}`, p.liked ? `Like entfernen @${p.handle}` : `Gefällt mir @${p.handle}`, "heart", () => like(p), p.liked ? "liked" : ""),
      icon(`comments:${p.id}`, `Kommentare @${p.handle}`, "comment", () => go({ kind: "comments", post: p }))], "social-post-actions")}
    <div className="social-post-copy"><strong>{p.likes.toLocaleString("de-DE")} Gefällt mir</strong><p><b>{p.handle}</b> {p.caption}</p>
      <small>{p.comments ? `${p.comments} Kommentare` : "Sei die erste Person, die kommentiert."}</small></div>
  </article>;
  const own = screen.kind === "profile" && screen.id === actor;
  let title = "iFruit";
  if (screen.kind === "comments") title = "Kommentare";
  if (screen.kind === "post") title = "Beitrag";
  if (screen.kind === "profile") title = profile?.id === screen.id ? profile.handle : "Profil";
  if (screen.kind === "accounts") title = "Deine Profile";
  if (screen.kind === "search") title = "Entdecken";
  if (screen.kind === "people") title = screen.mode === "followers" ? "Follower" : "Gefolgt";
  if (screen.kind === "compose") title = "Neuer Beitrag";
  const heading = <header className="social-heading">
    {screen.kind !== "feed" && controls([icon("back", "Zurück", "back", back)], "social-tools")}
    <h3 className={screen.kind === "feed" ? "social-wordmark" : ""}>{title}</h3>
    {actor > 0 && (own ? controls([icon("accounts", "Profil wechseln", "team", () => go({ kind: "accounts" }))], "social-tools")
      : screen.kind === "feed" ? controls([icon("search", "Profile suchen", "search", () => go({ kind: "search", query: "" })), icon("refresh", "Neue Beiträge laden", "refresh", () => { setBefore(undefined); setRevision((v) => v + 1); })], "social-tools") : null)}
  </header>;
  let content: ReactNode;
  if (!account) content = <><Empty icon="phone" title="Verbinden …" text="Deine Stadt in Bildern." />{controls([{ id: "retry", label: "Erneut verbinden", content: <span>Erneut verbinden</span>, run: () => run(home) }], "social-button-row")}</>;
  else if (!active) content = <><Empty icon="camera" title="Deine Perspektive zählt." text="Teile deine Momente. Entdecke die Stadt. Bleib mit deinen Leuten verbunden." />
    {controls([{ id: "register", label: "Profil erstellen", content: <span>Dein Profil erstellen</span>, run: () => profileForm() }], "social-button-row primary")}
    <p className="social-footnote">Ein persönliches Profil für deinen Charakter.</p></>;
  else if (screen.kind === "feed" || screen.kind === "post") content = <>
    {screen.kind === "feed" && <div className="social-feed-caption"><b>{screen.following ? "Deine Freunde" : "Für dich"}</b><span>{screen.following ? "Von den Profilen, denen du folgst" : "Momente aus ganz Los Santos"}</span></div>}
    {posts.map(renderPost)}{!posts.length && !busy && <Empty icon={screen.kind === "feed" && screen.following ? "team" : "gallery"} title="Hier beginnt deine Timeline." text={screen.kind === "feed" && screen.following ? "Folge Profilen, um ihre neuesten Beiträge hier zu sehen." : "Teile das erste Foto aus deiner Galerie."} />}
    {pageControl(posts[posts.length - 1]?.id)}</>;
  else if (screen.kind === "profile") content = profile?.id === screen.id ? <>
    <div className="social-profile-top"><Avatar name={profile.name} large />{controls([
      { id: "posts", label: "Beiträge anzeigen", content: <><b>{profile.posts}</b><span>Beiträge</span></>, run: () => { setSelected(posts.length ? `tile:${posts[0].id}` : "posts"); } },
      { id: "followers", label: "Follower anzeigen", content: <><b>{profile.followers}</b><span>Follower</span></>, run: () => go({ kind: "people", id: profile.id, mode: "followers" }) },
      { id: "following", label: "Gefolgte Profile anzeigen", content: <><b>{profile.follows}</b><span>Gefolgt</span></>, run: () => go({ kind: "people", id: profile.id, mode: "following" }) },
    ], "social-stats")}</div>
    <div className="social-bio"><strong>{profile.name}</strong><p>{profile.bio || "Willkommen auf meinem Profil."}</p>{own && <small>Angemeldet als @{active.handle}</small>}</div>
    {controls(own ? [{ id: "edit", label: "Profil bearbeiten", content: <span>Profil bearbeiten</span>, run: () => profileForm(active) },
      { id: "switch", label: "Konten wechseln", content: <span>Profile <span aria-hidden="true">⌄</span></span>, run: () => go({ kind: "accounts" }) }]
      : [{ id: "follow", label: profile.following ? "Nicht mehr folgen" : "Folgen", content: <span>{profile.following ? "Gefolgt ✓" : "Folgen"}</span>, run: () => follow(profile.id, !profile.following) }], `social-button-row ${!own && !profile.following ? "primary" : ""}`)}
    <div className="social-grid-label"><UiIcon name="grid" /></div>
    {Array.from({ length: Math.ceil(posts.length / 3) }, (_, row) => <div key={row}>{controls(posts.slice(row * 3, row * 3 + 3).map((p) => ({ id: `tile:${p.id}`, label: `Beitrag ${p.id}`, content: photo(p), run: () => go({ kind: "post", post: p }) })), "social-grid")}</div>)}
    {!posts.length && !busy && <Empty icon="camera" title="Noch keine Beiträge" text={own ? "Dein erstes Foto wartet in deiner Galerie." : "Hier erscheinen bald neue Momente."} />}{pageControl(posts[posts.length - 1]?.id)}
  </> : <Empty icon="person" title="Profil wird geladen …" text="" />;
  else if (screen.kind === "comments") content = <>
    <div className="social-caption"><Avatar name={screen.post.name} /><p><b>{screen.post.handle}</b> {screen.post.caption}</p></div>
    {controls([{ id: "comment", label: "Kommentar schreiben", content: <><Avatar name={active.name} /><span>Kommentiere als {active.handle} …</span><UiIcon name="compose" /></>, run: () => edit("Kommentar", [field("body", "Dein Kommentar", "", 400, true)], async (values, nonce) => {
      await request("comment", { id: screen.post.id, body: values.body.trim(), nonce }); if (alive.current) { setBefore(undefined); setRevision((v) => v + 1); }
    }, "Posten") }], "social-composer")}
    {comments.map((c) => <div className="social-comment" key={c.id}>{controls([{ id: `comment:${c.id}`, label: `Kommentar von ${c.name}`, content: <><Avatar name={c.name} /><span><b>{c.handle ?? c.name}</b><p>{c.body}</p><small>{date(c.created)}</small></span></>, run: () => { if (c.author) go({ kind: "profile", id: c.author }); } }])}</div>)}
    {!comments.length && !busy && <Empty icon="comment" title="Starte das Gespräch." text="Schreibe den ersten Kommentar." />}{pageControl(comments[comments.length - 1]?.id)}
  </>;
  else if (screen.kind === "accounts") content = <><p className="social-intro">Wähle das Profil, mit dem du postest, likest und anderen folgst.</p>
    {account.profiles.map((p) => <div key={p.id}>{controls([{ id: `account:${p.id}`, label: `Wechseln zu @${p.handle}`, content: <><Avatar name={p.name} /><span><strong>{p.handle}</strong><small>{p.name}</small></span><b>{p.id === actor ? "✓" : ""}</b></>, run: () => run(async () => {
      const data = await request("social_switch", { id: p.id }); if (alive.current && data?.kind === "social_home") { setAccount(data); go({ kind: "profile", id: data.active }, true); }
    }) }], "social-person")}</div>)}
    {account.profiles.length < account.slots && controls([{ id: "create", label: "Weiteres Profil erstellen", content: <><UiIcon name="plus" /><span>Profil hinzufügen</span></>, run: () => profileForm() }], "social-button-row")}
    <p className="social-footnote">{account.profiles.length} / {account.slots} Profile · Weitere Profile werden durch die Administration freigeschaltet.</p></>;
  else if (screen.kind === "search" || screen.kind === "people") content = <>
    {screen.kind === "search" && controls([{ id: "query", label: "Benutzername suchen", content: <><UiIcon name="search" /><span>{screen.query || "Benutzername suchen"}</span></>, run: () => edit("Profile suchen", [field("query", "Benutzername", screen.query, 24)], async (values) => { setScreen({ kind: "search", query: values.query.trim().replace(/^@/, "") }); setBefore(undefined); }, "Suchen") }], "social-search")}
    {people.map((p) => <div key={p.id}>{controls([{ id: `person:${p.id}`, label: `Profil @${p.handle}`, content: <><Avatar name={p.name} /><span><strong>{p.handle}</strong><small>{p.name}</small></span></>, run: () => go({ kind: "profile", id: p.id }) },
      ...(p.id !== actor ? [{ id: `follow:${p.id}`, label: `${p.following ? "Entfolgen" : "Folgen"} @${p.handle}`, content: <span>{p.following ? "Gefolgt" : "Folgen"}</span>, run: () => follow(p.id, !p.following), className: "social-follow" }] : [])], "social-person")}</div>)}
    {!people.length && !busy && <Empty icon="search" title="Noch niemand hier." text="Suche nach einem Benutzernamen oder entdecke Profile in der Timeline." />}{pageControl(people[people.length - 1]?.id)}
  </>;
  else content = <><div className="social-compose-heading"><strong>Aus deiner Galerie</strong><small>Teilen als @{active.handle}</small></div>
    {galleryError && <p className="social-intro">{galleryError}</p>}
    {Array.from({ length: Math.ceil(Math.min(24, photos.length - photoPage * 24) / 3) }, (_, row) => <div key={row}>{controls(photos.slice(photoPage * 24 + row * 3, photoPage * 24 + row * 3 + 3).map((p) => ({ id: `local:${p.id}`, label: `Foto ${date(p.created / 1000)}`, content: <div className="social-photo"><img src={p.url} alt="Foto aus deiner Galerie" /></div>, run: () => publish(p) })), "social-grid")}</div>)}
    {!photos.length && <Empty icon="gallery" title="Dein nächster Moment wartet." text="Nimm ein Foto mit der Kamera auf. Es bleibt privat, bis du es hier teilst." />}
    {photos.length > 24 && controls([{ id: "prevPhotos", label: "Vorherige Fotos", content: <span>‹ Zurück</span>, run: () => setPhotoPage(Math.max(0, photoPage - 1)) }, { id: "nextPhotos", label: "Nächste Fotos", content: <span>Weiter ›</span>, run: () => setPhotoPage(Math.min(Math.ceil(photos.length / 24) - 1, photoPage + 1)) }], "social-button-row")}
    {controls([{ id: "camera", label: "Foto aufnehmen", content: <><UiIcon name="camera" /><span>Foto aufnehmen</span></>, run: () => launch("camera") }], "social-button-row")}</>;
  const tabs = active && controls([
    { ...icon("tab:all", "Alle Beiträge", "home", () => go({ kind: "feed", following: false }, true)), content: <><UiIcon name="home" /><span>Alle</span></>, className: screen.kind === "feed" && !screen.following ? "active" : "" },
    { ...icon("tab:friends", "Freunde", "team", () => go({ kind: "feed", following: true }, true)), content: <><UiIcon name="team" /><span>Freunde</span></>, className: screen.kind === "feed" && screen.following ? "active" : "" },
    { ...icon("tab:new", "Neuer Fotobeitrag", "plus", () => go({ kind: "compose" })), content: <><UiIcon name="plus" /><span>Teilen</span></>, className: screen.kind === "compose" ? "active" : "" },
    { id: "tab:profile", label: "Mein Profil", run: () => go({ kind: "profile", id: actor }, true), content: <><Avatar name={active.name} /><span>Profil</span></>, className: own ? "active" : "" },
  ], "social-tabs");
  const current = groups.flat().find((a) => a.id === selected) ?? groups[0]?.[0];
  useEffect(() => { if (current && selected !== current.id) setSelected(current.id); }, [current?.id, selected]);
  useImperativeHandle(ref, () => ({ key: (key) => {
    if (form) return true;
    if (key === "back") return back();
    const row = Math.max(0, groups.findIndex((g) => g.some((a) => a.id === current?.id))), col = Math.max(0, groups[row]?.findIndex((a) => a.id === current?.id) ?? 0);
    if (key === "enter") { if (!busyRef.current) current?.run(); return true; }
    if (key === "down" && row >= groups.length - 1) return false;
    const next = Math.max(0, Math.min(groups.length - 1, row + (key === "down" ? 1 : key === "up" ? -1 : 0)));
    setSelected(groups[next]?.[Math.max(0, Math.min(groups[next].length - 1, col + (key === "right" ? 1 : key === "left" ? -1 : 0)))]?.id ?? ""); return true;
  } }));
  return <div ref={root} className="phone-communication phone-social" data-social-screen={screen.kind} aria-label="iFruit Social Media">
    {heading}{error && <div className="phone-app-error" role="status">{error}</div>}
    {form ? <div className="social-form-wrap">{screen.kind === "compose" && draftPhoto && <img className="social-draft-photo" src={draftPhoto} alt="Foto für deinen Beitrag" />}<PhoneForm form={form} setForm={setForm} busy={busy} session={session} preview={preview} active={open} submit={() => run(async () => {
      await form.save(Object.fromEntries(form.fields.map((f) => [f.key, f.value])), form.nonce);
      if (alive.current) setForm((current) => current?.nonce === form.nonce ? null : current);
    })} /></div> : <><div className="social-scroll" key={`${screen.kind}:${before ?? 0}:${actor}`}>{content}</div>{tabs}</>}
  </div>;
});
