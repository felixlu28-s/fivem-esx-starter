import { forwardRef, useEffect, useImperativeHandle, useRef, useState, type ReactNode } from "react";
import { UiIcon } from "../components/UiIcon";
import { PhoneForm, type PhoneFormState } from "../components/PhoneForm";
import { useGalleryScope } from "../lib/useGalleryScope";
import { listLocalMedia, loadLocalMedia, removeLocalMedia, type GalleryItem } from "../lib/phoneGallery";
import { phoneRequest } from "../lib/phoneRequest";
import type { PhoneApp } from "../lib/phone";
import type { PhoneWorkspaceHandle } from "./PhoneWorkspace";
import "../phone-camera.css";
import { forPublication } from "../lib/phonePublication";

type Action = { id: string; label: string; content: ReactNode; run: () => void };
const date = (value: number) => new Date(value).toLocaleString("de-DE", { timeZone: "Europe/Berlin", day: "2-digit", month: "long", hour: "2-digit", minute: "2-digit" });
export const PhoneGallery = forwardRef<PhoneWorkspaceHandle, { session: string; preview: boolean; focused: boolean; open: boolean; launch: (app: PhoneApp) => void }>(
  function PhoneGallery({ session, preview, focused, open, launch }, ref) {
    const { scope, error: scopeError } = useGalleryScope(session, preview);
    const [items, setItems] = useState<(GalleryItem & { url: string })[]>([]), [itemId, setItemId] = useState("");
    const [image, setImage] = useState(""), [error, setError] = useState(""), [busy, setBusy] = useState(false), [revision, setRevision] = useState(0);
    const [filter, setFilter] = useState<"all" | "photo" | "video">("all"), [page, setPage] = useState(0), [selected, setSelected] = useState("");
    const [playing, setPlaying] = useState(false), [time, setTime] = useState(0), [form, setForm] = useState<PhoneFormState | null>(null);
    const root = useRef<HTMLDivElement>(null), video = useRef<HTMLVideoElement>(null), alive = useRef(true), busyRef = useRef(false);
    const item = items.find((value) => value.id === itemId);
    const run = (work: () => Promise<void>) => {
      if (busyRef.current) return; busyRef.current = true; setBusy(true); setError("");
      void work().catch((e: unknown) => { if (alive.current) setError(e instanceof Error ? e.message : "Galerie nicht verfügbar."); })
        .finally(() => { busyRef.current = false; if (alive.current) setBusy(false); });
    };
    useEffect(() => { alive.current = true; return () => { alive.current = false; }; }, []);
    useEffect(() => {
      if (!scope) return;
      let cancelled = false; const urls: string[] = [];
      void listLocalMedia(scope).then((data) => {
        if (cancelled) return;
        setItems(data.items.map((entry) => { const url = URL.createObjectURL(entry.thumbnail); urls.push(url); return { ...entry, url }; }));
        if (data.damaged) setError(`${data.damaged} beschädigte oder veränderte Aufnahme(n) wurden ausgeblendet.`);
      }).catch((e: unknown) => { if (!cancelled) setError(e instanceof Error ? e.message : "Galerie nicht verfügbar."); });
      return () => { cancelled = true; urls.forEach((url) => URL.revokeObjectURL(url)); };
    }, [scope, revision]);
    useEffect(() => {
      setImage(""); setPlaying(false); setTime(0);
      if (!scope || !itemId) return;
      let cancelled = false, url = "";
      void loadLocalMedia(scope, itemId).then((data) => { if (!cancelled) { url = URL.createObjectURL(data.blob); setImage(url); } })
        .catch((e: unknown) => { if (!cancelled) setError(e instanceof Error ? e.message : "Aufnahme nicht verfügbar."); });
      return () => { cancelled = true; if (url) URL.revokeObjectURL(url); };
    }, [scope, itemId]);
    useEffect(() => { if (!open || form) { video.current?.pause(); setPlaying(false); } }, [open, !!form]);
    useEffect(() => {
      const tile = root.current?.querySelector<HTMLElement>(".gallery-tile.selected"), scroll = root.current?.querySelector<HTMLElement>(".gallery-grid-scroll");
      if (!tile || !scroll) return;
      const bounds = tile.getBoundingClientRect(), viewport = scroll.getBoundingClientRect();
      // Scroll only the gallery, never the phone shell or the hidden game viewport.
      if (bounds.top < viewport.top) scroll.scrollTop += bounds.top - viewport.top;
      else if (bounds.bottom > viewport.bottom) scroll.scrollTop += bounds.bottom - viewport.bottom;
    }, [selected]);
    const back = () => { if (itemId) { setItemId(""); setError(""); setSelected(`open:${itemId}`); return true; } return false; };
    const groups: Action[][] = [];
    const controls = (actions: Action[], className = "") => {
      groups.push(actions);
      return <div className={`gallery-controls ${className}`}>{actions.map((action) => <div key={action.id} role="button" aria-label={action.label} aria-pressed={focused && !form && (selected || groups[0]?.[0]?.id) === action.id}
        data-gallery-action={action.id} aria-disabled={busy} className={`${action.id.startsWith("open:") ? "gallery-tile" : "gallery-control"} ${focused && !form && (selected || groups[0]?.[0]?.id) === action.id ? "selected" : ""}`}>{action.content}</div>)}</div>;
    };
    const filtered = items.filter((entry) => filter === "all" || entry.kind === filter), pages = Math.max(1, Math.ceil(filtered.length / 24));
    const tiles = filtered.slice(Math.min(page, pages - 1) * 24, Math.min(page, pages - 1) * 24 + 24);
    const content = itemId ? <>
      <header className="gallery-heading">{controls([{ id: "back", label: "Zur Galerie", content: <UiIcon name="back" />, run: back }])}<div><strong>{item?.kind === "video" ? "Video" : "Foto"}</strong><small>{item ? date(item.created) : "Aufnahme"}</small></div></header>
      <div className="gallery-viewer">{image && (item?.kind === "video"
        ? <video ref={video} src={image} playsInline muted onTimeUpdate={() => setTime(video.current?.currentTime ?? 0)} onEnded={() => setPlaying(false)} aria-label="Aufgenommenes Video" />
        : <img src={image} alt="Aufgenommenes Foto" />)}</div>
      {item?.kind === "video" && <><small className="gallery-play-time">{Math.floor(time)} / {Math.ceil(item.duration)} Sekunden · ohne Ton</small>{controls([
        { id: "rewind", label: "5 Sekunden zurück", content: <span>−5 s</span>, run: () => { if (video.current) video.current.currentTime = Math.max(0, video.current.currentTime - 5); } },
        { id: "play", label: playing ? "Pausieren" : "Abspielen", content: <UiIcon name={playing ? "pause" : "play"} />, run: () => { if (video.current) { if (playing) { video.current.pause(); setPlaying(false); } else void video.current.play().then(() => setPlaying(true)).catch(() => setError("Video konnte nicht abgespielt werden.")); } } },
        { id: "forward", label: "5 Sekunden vor", content: <span>+5 s</span>, run: () => { if (video.current) video.current.currentTime = Math.min(item.duration, video.current.currentTime + 5); } },
      ], "gallery-playback")}</>}
      {controls([
        { id: "delete", label: "Aufnahme löschen", content: <><UiIcon name="trash" /><span>Löschen</span></>, run: () => setForm({ title: "Aufnahme endgültig löschen?", fields: [], nonce: crypto.randomUUID(), submitLabel: "Löschen", save: async () => {
          await removeLocalMedia(scope, itemId); setItemId(""); setSelected(""); setRevision((v) => v + 1);
        } }) },
        ...(item?.kind === "photo" ? [{ id: "share", label: "Auf iFruit veröffentlichen", content: <><UiIcon name="arrow" /><span>iFruit</span></>, run: () => run(async () => {
          const state = await phoneRequest(session, preview, "social_home", {});
          if (!state.ok || state.phone?.kind !== "social_home") throw new Error("iFruit konnte nicht geladen werden.");
          const actor = state.phone.active, identity = state.phone.profiles.find((p) => p.id === actor);
          if (!identity) { launch("ifruit"); return; }
          if (!alive.current) return;
          setForm({ title: `Teilen als @${identity.handle}`, fields: [{ key: "caption", label: "Bildunterschrift", value: "", max: 1000, multiline: true }], nonce: crypto.randomUUID(), submitLabel: "Veröffentlichen", save: async (values: Record<string, string>, nonce: string) => {
          const media = await loadLocalMedia(scope, itemId);
          const response = await phoneRequest(session, preview, "publish_local", { actor, image: await forPublication(media.blob), caption: values.caption, nonce });
          if (!response.ok) throw new Error("Der Beitrag konnte nicht veröffentlicht werden.");
          launch("ifruit");
        } }); }) }] : []),
      ], "gallery-actions")}
    </> : <>
      <header className="gallery-heading"><div><h3>Galerie</h3><small>{items.length} Aufnahmen · Auf diesem Gerät</small></div>{controls([{ id: "camera", label: "Kamera öffnen", content: <UiIcon name="camera" />, run: () => launch("camera") }])}</header>
      <div className="gallery-grid-scroll">{Array.from({ length: Math.ceil(tiles.length / 3) }, (_, row) => <div key={row}>{controls(tiles.slice(row * 3, row * 3 + 3).map((entry) => ({ id: `open:${entry.id}`, label: `${entry.kind === "photo" ? "Foto" : "Video"} ${date(entry.created)}`, content: <><img src={entry.url} alt="" />{entry.kind === "video" && <small><UiIcon name="video" />{Math.ceil(entry.duration)} s</small>}</>, run: () => { setItemId(entry.id); setSelected("back"); setError(""); } })), "gallery-grid")}</div>)}
        {!tiles.length && <div className="gallery-empty"><UiIcon name="gallery" /><strong>Noch keine Aufnahmen</strong><p>Deine Fotos und Videos erscheinen hier.</p></div>}
      </div>
      {pages > 1 && controls([{ id: "prev", label: "Vorherige Seite", content: <span>‹</span>, run: () => { setPage(Math.max(0, page - 1)); setSelected("camera"); } }, { id: "next", label: "Nächste Seite", content: <span>{page + 1} / {pages} ›</span>, run: () => { setPage(Math.min(pages - 1, page + 1)); setSelected("camera"); } }], "gallery-pages")}
      {controls((["all", "photo", "video"] as const).map((value, index) => ({ id: `filter:${value}`, label: ["Alle Aufnahmen", "Nur Fotos", "Nur Videos"][index], content: <span className={filter === value ? "active" : ""}>{["Alle", "Fotos", "Videos"][index]}</span>, run: () => { setFilter(value); setPage(0); setSelected(`filter:${value}`); } })), "gallery-filters")}
    </>;
    const current = groups.flat().find((action) => action.id === selected) ?? groups[0]?.[0];
    useEffect(() => { if (current && selected !== current.id) setSelected(current.id); }, [current?.id, selected]);
    useImperativeHandle(ref, () => ({ key: (key) => {
      if (form) return true;
      if (key === "back") return back();
      const row = Math.max(0, groups.findIndex((group) => group.some((action) => action.id === current?.id))), col = Math.max(0, groups[row]?.findIndex((action) => action.id === current?.id) ?? 0);
      if (key === "enter") { if (!busyRef.current) current?.run(); return true; }
      if (key === "down" && row === groups.length - 1) return false;
      const next = Math.max(0, Math.min(groups.length - 1, row + (key === "down" ? 1 : key === "up" ? -1 : 0)));
      setSelected(groups[next]?.[Math.max(0, Math.min(groups[next].length - 1, col + (key === "right" ? 1 : key === "left" ? -1 : 0)))]?.id ?? ""); return true;
    } }));
    return <div className="phone-gallery-app" ref={root}>{(error || scopeError) && <p className="gallery-error" role="status">{error || scopeError}</p>}{form
      ? <PhoneForm form={form} setForm={setForm} busy={busy} session={session} preview={preview} active={open} submit={() => run(async () => { await form.save(Object.fromEntries(form.fields.map((f) => [f.key, f.value])), form.nonce); if (alive.current) setForm((current) => current?.nonce === form.nonce ? null : current); })} />
      : content}</div>;
  }
);
