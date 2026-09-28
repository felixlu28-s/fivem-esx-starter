import { useEffect, useState } from "react";
import { UiIcon } from "../components/UiIcon";
import { loadingConfig as config } from "./config";
import { initialLoading, loadingLabel, reduceLoading, type LoadingState } from "./protocol";
import "./loading.css";

declare global {
  interface Window {
    rpLoadingEarly?: LoadingState;
    rpLoadingCapture?: (event: MessageEvent<unknown>) => void;
  }
}

export function LoadingScreen({ preview = false }: { preview?: boolean }) {
  const [state, setState] = useState<LoadingState>(() => window.rpLoadingEarly ?? initialLoading);
  const [tipIndex, setTipIndex] = useState(0);
  const [slow, setSlow] = useState(false);
  useEffect(() => {
    document.documentElement.classList.toggle("join-handoff", state.phase === "exiting");
    return () => document.documentElement.classList.remove("join-handoff");
  }, [state.phase]);
  useEffect(() => {
    const listener = (event: MessageEvent<unknown>) => setState((s) => reduceLoading(s, event.data));
    window.addEventListener("message", listener);
    // React has installed its listener; now transfer and release the early buffer.
    if (window.rpLoadingEarly) setState(window.rpLoadingEarly);
    if (window.rpLoadingCapture) window.removeEventListener("message", window.rpLoadingCapture);
    delete window.rpLoadingEarly;
    delete window.rpLoadingCapture;
    return () => window.removeEventListener("message", listener);
  }, []);
  useEffect(() => {
    const timer = window.setTimeout(() => setSlow(true), 35000);
    setSlow(false);
    return () => window.clearTimeout(timer);
  }, [state.fraction, state.phase]);
  useEffect(() => {
    const timer = window.setInterval(() => {
      if (!document.hidden) setTipIndex((index) => (index + 1) % config.tips.length);
    }, config.tipIntervalMs);
    return () => window.clearInterval(timer);
  }, []);
  useEffect(() => {
    if (!preview) return;
    // Only the explicit browser preview simulates progress. Live never ticks up.
    let tick = 0;
    const timer = window.setInterval(() => {
      tick = (tick + 1) % 45;
      setState(tick > 37 ? { fraction: 1, phase: "scene" } : { fraction: tick / 37, phase: "assets" });
    }, 850);
    return () => window.clearInterval(timer);
  }, [preview]);
  const tip = config.tips[tipIndex];
  const percent = state.fraction === null ? null : Math.floor(state.fraction * 100);
  return (
    <main className={`join-screen${state.phase === "exiting" ? " join-screen-exiting" : ""}`} aria-label="Server-Ladebildschirm">
      <img className="join-art" src={config.artwork} alt="" draggable={false} fetchPriority="high" />
      <div className="join-shade" aria-hidden="true" />
      <header className="join-header">
        <div className="join-brand"><span className="join-brand-mark"><UiIcon name="plane" /></span><div><strong>{config.brand}</strong><small>{config.subtitle}</small></div></div>
        <span className="join-edition"><i /> SAN ANDREAS <span> / </span> LOS SANTOS</span>
      </header>
      <section className="join-intro">
        <p className="join-kicker">WILLKOMMEN ZUHAUSE</p>
        <h1>{config.headline[0]}<br /><span>{config.headline[1]}</span></h1>
        <p className="join-description">{config.introduction}</p>
        <span className="join-intro-rule" aria-hidden="true" />
      </section>
      <footer className="join-footer">
        <div className="join-tip">
          <span className="join-tip-label">LEBEN IN LOS SANTOS</span>
          <div key={tipIndex} className="join-tip-copy"><h2>{tip.title}</h2><p>{tip.text}</p></div>
          <div className="join-tip-pages" aria-hidden="true">{config.tips.map((_, i) => <i key={i} className={i === tipIndex ? "active" : ""} />)}</div>
        </div>
        <div className="join-loading">
          <div className="join-loading-top"><span className="join-spinner" aria-hidden="true" /><p role="status">{loadingLabel(state)}</p><span className="join-percent">{percent === null ? "…" : `${percent}%`}</span></div>
          <div className={`join-track${percent === null ? " join-track-pending" : ""}`} role="progressbar" aria-label="FiveM-Ladefortschritt" aria-valuemin={0} aria-valuemax={100} aria-valuenow={percent ?? undefined} aria-valuetext={percent === null ? "Verbindung wird vorbereitet" : `${percent} Prozent der Spieldaten geladen`}><span style={{ transform: `scaleX(${state.fraction ?? 0})` }} /></div>
          <div className="join-loading-note"><span>{slow ? "Das Laden dauert etwas länger. Die Verbindung bleibt geöffnet." : "Beim ersten Besuch kann das Laden etwas länger dauern."}</span>{preview && <b>VORSCHAU</b>}</div>
        </div>
      </footer>
    </main>
  );
}
