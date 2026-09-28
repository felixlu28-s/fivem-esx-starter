import { useEffect, useRef, useState } from "react";
import { isRecord } from "../lib/nui";
import { UiIcon, type UiIconName } from "../components/UiIcon";
import {
  isScreenId,
  isViewportId,
  screens,
  viewports,
  type ScreenId,
  type ViewportId,
} from "./catalog";
import "./studio.css";

const screenIcons: Record<ScreenId, UiIconName> = {
  banking: 'bank',
  'atm-maze': 'bank',
  'atm-liberty': 'bank',
  loadscreen: "plane",
  clothing: "shop",
  phone: "phone",
  hud: "microphone",
  interaction: "keyboard",
  nativeui: "keyboard",
  admin: "settings",
  weaponshop: "shop",
  garage: "shop",
  "garage-dev": "settings",
  shop: "shop",
  crafting: "craft",
  characters: "team",
  creator: "person",
  me: "person",
  settings: "keyboard",
  inventory: "bag",
  organizations: "organization",
  loading: "plane",
  error: "warning",
  welcome: "message",
};

export default function BrowserStudio() {
  const [active, setActive] = useState<ScreenId | null>(() => {
    const initial = new URLSearchParams(location.search).get("preview");
    return initial === "none" ? null : isScreenId(initial) ? initial : "me";
  });
  const [viewport, setViewport] = useState<ViewportId>("auto");
  const [background, setBackground] = useState("scene");
  const [generation, setGeneration] = useState(0);
  const [filter, setFilter] = useState("");
  const [notice, setNotice] = useState(
    "Bereit. Wähle links eine Oberfläche aus.",
  );
  const [space, setSpace] = useState({ width: 1280, height: 720 });
  const canvas = useRef<HTMLDivElement>(null);
  const frame = useRef<HTMLIFrameElement>(null);
  const selected = screens.find((screen) => screen.id === active);
  const preset = viewports[viewport];
  const width = preset.width || Math.max(320, Math.floor(space.width));
  const height = preset.height || Math.max(240, Math.floor(space.height));
  const scale = Math.min(1, space.width / width, space.height / height);
  const src = active === "loadscreen" ? "./loading.html?preview=1" : active ? `./?view=${active}` : "";
  const syncBackground = () => {
    frame.current?.contentDocument?.documentElement.classList.toggle(
      "studio-photo-background",
      background === "gta",
    );
  };

  useEffect(syncBackground, [background]);

  useEffect(() => {
    const node = canvas.current;
    if (!node) return;
    const observer = new ResizeObserver(([entry]) => {
      if (entry)
        setSpace({
          width: Math.max(1, entry.contentRect.width),
          height: Math.max(1, entry.contentRect.height),
        });
    });
    observer.observe(node);
    return () => observer.disconnect();
  }, []);
  useEffect(() => {
    const url = new URL(location.href);
    url.searchParams.set("preview", active ?? "none");
    history.replaceState(null, "", url);
  }, [active]);
  useEffect(() => {
    const listener = (event: MessageEvent<unknown>) => {
      if (
        event.origin !== location.origin ||
        event.source !== frame.current?.contentWindow ||
        !isRecord(event.data)
      )
        return;
      if (
        event.data.action === "studio:visibility" &&
        event.data.visible === false
      ) {
        setActive(null);
        setNotice("UI geschlossen. Du kannst sie links erneut einblenden.");
      }
    };
    window.addEventListener("message", listener);
    return () => window.removeEventListener("message", listener);
  }, []);

  const toggle = (id: ScreenId) => {
    setActive((current) => (current === id ? null : id));
    setNotice(
      active === id ? "UI ausgeblendet." : "Vorschau mit Demodaten geöffnet.",
    );
  };
  const reset = () => {
    if (active === "settings") localStorage.removeItem("rp-input-preview");
    setGeneration((current) => current + 1);
    setNotice("Demozustand zurückgesetzt.");
  };

  return (
    <div className="studio-shell">
      <aside className="studio-sidebar" aria-label="UI-Auswahl">
        <header className="studio-brand">
          <span aria-hidden="true">
            rp<span>_</span>
          </span>
          <div>
            <strong>UI Studio</strong>
            <small>FIVEM · BROWSER WORKSPACE</small>
          </div>
        </header>
        <div className="studio-sidebar-intro">
          <h1>Deine Oberflächen.</h1>
          <p>Einblenden, ausprobieren, verfeinern.</p>
        </div>
        <label className="studio-search">
          <span>UI suchen</span>
          <input
            type="search"
            placeholder="Oberfläche suchen …"
            value={filter}
            onChange={(e) => setFilter(e.target.value)}
          />
        </label>
        <nav className="studio-list" aria-label="Verfügbare Oberflächen">
          {[...new Set(screens.map((screen) => screen.group))].map((group) => {
            const entries = screens.filter(
              (screen) =>
                screen.group === group &&
                `${screen.title} ${screen.description}`
                  .toLocaleLowerCase("de")
                  .includes(filter.toLocaleLowerCase("de")),
            );
            if (!entries.length) return null;
            return (
              <section key={group}>
                <h2>{group}</h2>
                {entries.map((screen) => (
                  <button
                    type="button"
                    key={screen.id}
                    data-screen={screen.id}
                    className={`studio-screen ${active === screen.id ? "studio-screen-active" : ""}`}
                    aria-pressed={active === screen.id}
                    onClick={() => toggle(screen.id)}
                  >
                    <span className="studio-screen-symbol" aria-hidden="true">
                      <UiIcon name={screenIcons[screen.id]} />
                    </span>
                    <span className="studio-screen-label">
                      <strong>{screen.title}</strong>
                      <small>
                        {active === screen.id
                          ? "Sichtbar · zum Ausblenden klicken"
                          : screen.description}
                      </small>
                    </span>
                    <i className="studio-visibility" aria-hidden="true" />
                  </button>
                ))}
              </section>
            );
          })}
          {!screens.some((screen) =>
            `${screen.title} ${screen.description}`
              .toLocaleLowerCase("de")
              .includes(filter.toLocaleLowerCase("de")),
          ) && (
            <p className="studio-no-results">
              Keine passende Oberfläche gefunden.
            </p>
          )}
        </nav>
        <section className="studio-source">
          <p>HIER BEARBEITEN</p>
          {selected ? (
            <>
              <code>src/{selected.source}</code>
              <code>src/{selected.css}</code>
            </>
          ) : (
            <span>Wähle eine Oberfläche aus.</span>
          )}
          <small>
            React oder CSS speichern. Die Vorschau aktualisiert sich
            automatisch.
          </small>
        </section>
        <footer className="studio-sidebar-footer">
          <i /> Demodaten · kein Spiel erforderlich
        </footer>
      </aside>

      <div className="studio-workspace">
        <header className="studio-toolbar">
          <div className="studio-current">
            <p>LIVE-VORSCHAU</p>
            <h2>{selected?.title ?? "Keine UI eingeblendet"}</h2>
          </div>
          <div className="studio-tools">
            <label>
              <span>Auflösung</span>
              <select
                aria-label="Auflösung"
                value={viewport}
                onChange={(e) => {
                  if (isViewportId(e.target.value)) setViewport(e.target.value);
                }}
              >
                {Object.entries(viewports).map(([id, value]) => (
                  <option key={id} value={id}>
                    {value.label}
                  </option>
                ))}
              </select>
            </label>
            <label>
              <span>Hintergrund</span>
              <select
                aria-label="Hintergrund"
                value={background}
                onChange={(e) => setBackground(e.target.value)}
              >
                <option value="scene">Dunkle Szene</option>
                <option value="gta">GTA · Straßenszene</option>
                <option value="checker">Transparenzraster</option>
                <option value="light">Hell</option>
              </select>
            </label>
            <button
              className="studio-icon-button"
              aria-label="Demozustand zurücksetzen"
              title="Neu starten; in den Einstellungen auch die Demobelegung zurücksetzen"
              disabled={!active}
              onClick={reset}
            >
              ↻
            </button>
          </div>
        </header>
        <div className="studio-stage-header">
          <span>
            <i className={active ? "studio-live" : ""} />
            {active ? "Interaktive Vorschau" : "Vorschau pausiert"}
          </span>
          <span>
            {width} × {height} <b>·</b> {Math.round(scale * 100)} %
          </span>
          <div>
            <button
              disabled={!active}
              onClick={() => {
                setActive(null);
                setNotice("UI ausgeblendet.");
              }}
            >
              UI ausblenden
            </button>
            {active && (
              <a href={src} target="_blank" rel="noreferrer">
                Einzeln öffnen ↗
              </a>
            )}
          </div>
        </div>
        <div className="studio-canvas" ref={canvas}>
          {selected ? (
            <div
              className={`studio-frame studio-background-${background}`}
              style={{ width: width * scale, height: height * scale }}
            >
              <iframe
                ref={frame}
                key={`${active}-${generation}`}
                title={`UI-Vorschau: ${selected.title}`}
                src={src}
                onLoad={syncBackground}
                style={{ width, height, transform: `scale(${scale})` }}
              />
            </div>
          ) : (
            <div className="studio-empty">
              <div aria-hidden="true">▧</div>
              <p>PLATZ FÜR DEINE IDEEN</p>
              <h2>Die Bühne gehört dir.</h2>
              <span>
                Wähle links eine UI, um sie einzublenden.
                <br />
                Ein erneuter Klick blendet sie wieder aus.
              </span>
            </div>
          )}
        </div>
        <footer className="studio-status">
          <span role="status">{notice}</span>
          <span>
            UI-Interaktionen sind simuliert. 3D-Peds und Spielaktionen benötigen
            FiveM.
          </span>
        </footer>
      </div>
    </div>
  );
}
