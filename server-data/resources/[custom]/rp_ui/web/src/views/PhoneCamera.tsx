import { forwardRef, useEffect, useImperativeHandle, useRef, useState } from "react";
import { UiIcon } from "../components/UiIcon";
import { useGalleryScope } from "../lib/useGalleryScope";
import { galleryLimits, listLocalMedia, recordLocalVideo, takeLocalPhoto, type LocalRecording } from "../lib/phoneGallery";
import type { PhoneMedia } from "../lib/usePhoneMedia";
import type { PhoneApp } from "../lib/phone";
import type { PhoneWorkspaceHandle } from "./PhoneWorkspace";
import "../phone-camera.css";

export const PhoneCamera = forwardRef<PhoneWorkspaceHandle, { session: string; preview: boolean; open: boolean; focused: boolean; media: PhoneMedia; launch: (app: PhoneApp) => void }>(
  function PhoneCamera({ session, preview, open, focused, media, launch }, ref) {
    const { scope, error: scopeError } = useGalleryScope(session, preview);
    const [mode, setMode] = useState<"photo" | "video">("photo"), [position, setPosition] = useState([2, 1]);
    const [busy, setBusy] = useState(false), [recording, setRecording] = useState(false), [seconds, setSeconds] = useState(0);
    const [error, setError] = useState(""), [flash, setFlash] = useState(false), [thumbnail, setThumbnail] = useState("");
    const [revision, setRevision] = useState(0);
    const video = useRef<HTMLVideoElement>(null), active = useRef<LocalRecording | null>(null), busyRef = useRef(false), alive = useRef(true);
    const ready = !!scope && !!media.capture?.ready && !scopeError;
    const zooms = [.5, 1, 2, 3];
    useEffect(() => { alive.current = true; return () => { alive.current = false; active.current?.stop(); }; }, []);
    useEffect(() => {
      if (open) { media.setMode("rear"); media.setZoom(1); }
      else active.current?.stop();
    }, [open]);
    useEffect(() => {
      const element = video.current;
      if (element) { element.srcObject = media.capture?.video() ?? null; if (element.srcObject) void element.play().catch(() => undefined); }
      return () => { if (element) element.srcObject = null; };
    }, [media.capture]);
    useEffect(() => {
      if (!scope) return;
      let url = "", cancelled = false;
      void listLocalMedia(scope).then(({ items }) => { if (!cancelled) { url = items[0] ? URL.createObjectURL(items[0].thumbnail) : ""; setThumbnail(url); } }).catch(() => undefined);
      return () => { cancelled = true; if (url) URL.revokeObjectURL(url); };
    }, [scope, revision]);
    useEffect(() => { if (!flash) return; const timer = window.setTimeout(() => setFlash(false), 130); return () => window.clearTimeout(timer); }, [flash]);
    useEffect(() => {
      if (!recording) return;
      const start = performance.now(); setSeconds(0);
      const timer = window.setInterval(() => setSeconds(Math.min(galleryLimits.seconds, Math.floor((performance.now() - start) / 1000))), 250);
      return () => window.clearInterval(timer);
    }, [recording]);
    const shoot = () => {
      if (active.current) { busyRef.current = true; setBusy(true); active.current.stop(); return; }
      if (!ready || busyRef.current || !media.capture) return;
      setError("");
      if (mode === "photo") {
        busyRef.current = true; setBusy(true); setFlash(true);
        void takeLocalPhoto(scope, media.capture).then(() => { if (alive.current) setRevision((v) => v + 1); })
          .catch((e: unknown) => { if (alive.current) setError(e instanceof Error ? e.message : "Foto konnte nicht gespeichert werden."); })
          .finally(() => { busyRef.current = false; if (alive.current) setBusy(false); });
      } else {
        try {
          const recorder = recordLocalVideo(scope, media.capture); active.current = recorder; setRecording(true);
          void recorder.finished.then(() => { if (alive.current) setRevision((v) => v + 1); })
            .catch((e: unknown) => { if (alive.current) setError(e instanceof Error ? e.message : "Video konnte nicht gespeichert werden."); })
            .finally(() => { active.current = null; busyRef.current = false; if (alive.current) { setRecording(false); setBusy(false); } });
        } catch (e) { setError(e instanceof Error ? e.message : "Videoaufnahme nicht verfügbar."); }
      }
    };
    const labels = [zooms.map((zoom) => `${zoom}× Zoom`), ["Video", "Foto"], ["Galerie öffnen", recording ? "Aufnahme stoppen" : mode === "photo" ? "Foto aufnehmen" : "Video aufnehmen", "Kamera wechseln"]];
    const selected = (row: number, column: number) => focused && position[0] === row && position[1] === column;
    useImperativeHandle(ref, () => ({ key: (key) => {
      if (key === "back") { if (active.current && !busyRef.current) { shoot(); return true; } return false; }
      const [row, column] = position;
      if (key === "down" && row === 2) return false;
      if (key === "up" || key === "down") { const next = Math.max(0, Math.min(2, row + (key === "down" ? 1 : -1))); setPosition([next, Math.min(column, labels[next].length - 1)]); return true; }
      if (key === "left" || key === "right") { setPosition([row, Math.max(0, Math.min(labels[row].length - 1, column + (key === "right" ? 1 : -1)))]); return true; }
      if (key === "enter" && !busyRef.current) {
        if (row === 0) media.setZoom(zooms[column]);
        if (row === 1 && !active.current) setMode(column === 0 ? "video" : "photo");
        if (row === 2 && column === 0 && !active.current) launch("gallery");
        if (row === 2 && column === 1) shoot();
        if (row === 2 && column === 2) media.setMode(media.mode === "selfie" ? "rear" : "selfie");
      }
      return true;
    } }));
    return <div className={`phone-camera-app ${recording ? "recording" : ""}`} aria-label="Kamera">
      <div className="camera-viewfinder">
        <video ref={video} muted autoPlay playsInline aria-label="Kameravorschau" />
        {!media.capture && <div className="camera-loading">Kamera wird geöffnet …</div>}
        <div className="camera-top"><span>{mode === "video" ? "HD · ohne Ton" : "FOTO · 3:4"}</span><span>{recording ? `● 00:${seconds.toString().padStart(2, "0")}` : media.mode === "selfie" ? "Frontkamera" : "Rückkamera"}</span></div>
        {flash && <div className="camera-flash" />}
        <div className="camera-focus" aria-hidden="true" />
        <div className="camera-zoom">{zooms.map((zoom, index) => <div key={zoom} role="button" aria-label={labels[0][index]} aria-pressed={selected(0, index)} className={`${media.zoom === zoom ? "active" : ""} ${selected(0, index) ? "selected" : ""}`}>{zoom}<small>×</small></div>)}</div>
      </div>
      {(error || scopeError || media.error) && <div className="camera-error" role="status">{error || scopeError || media.error}</div>}
      <div className="camera-modes">{["Video", "Foto"].map((label, index) => <div key={label} role="button" aria-label={label} aria-pressed={selected(1, index)} className={`${mode === (index === 0 ? "video" : "photo") ? "active" : ""} ${selected(1, index) ? "selected" : ""}`}>{label}</div>)}</div>
      <div className="camera-bottom">
        <div role="button" aria-label={labels[2][0]} aria-pressed={selected(2, 0)} aria-disabled={recording || busy} className={`camera-library ${selected(2, 0) ? "selected" : ""}`}>{thumbnail ? <img src={thumbnail} alt="Letzte Aufnahme" /> : <UiIcon name="gallery" />}</div>
        <div role="button" aria-label={labels[2][1]} aria-pressed={selected(2, 1)} aria-disabled={busy || !ready} className={`camera-shutter ${mode} ${selected(2, 1) ? "selected" : ""}`}><span /></div>
        <div role="button" aria-label={labels[2][2]} aria-pressed={selected(2, 2)} className={`camera-flip ${selected(2, 2) ? "selected" : ""}`}><UiIcon name="refresh" /></div>
      </div>
    </div>;
  }
);
