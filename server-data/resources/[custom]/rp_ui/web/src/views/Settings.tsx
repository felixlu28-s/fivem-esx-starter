import {
  useEffect,
  useRef,
  useState,
  type CSSProperties,
  type ReactNode,
} from "react";
import { UiIcon } from "../components/UiIcon";
import { useMenuToggle } from "../lib/menuToggle";
import {
  errorLabel,
  fetchNui,
  isBrowser,
  type BindingPayload,
  type InputKey,
} from "../lib/nui";

type Confirmation =
  | { kind: "replace"; key: InputKey; names: string[] }
  | { kind: "close" }
  | { kind: "reset" };
const contextLabels: Record<string, string> = {
  all: "Überall",
  foot: "Zu Fuß",
  vehicle: "Im Fahrzeug",
  air: "Im Flugzeug",
};

function Confirm({
  title,
  children,
  busy,
  accept,
  onAccept,
  onCancel,
}: {
  title: string;
  children: ReactNode;
  busy: boolean;
  accept: string;
  onAccept: () => void;
  onCancel: () => void;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const node = ref.current;
    node?.showModal();
    return () => node?.close();
  }, []);
  return (
    <dialog
      ref={ref}
      className="binding-dialog"
      aria-labelledby="confirmation-title"
      onCancel={(event) => {
        event.preventDefault();
        if (!busy) onCancel();
      }}
    >
      <span className="dialog-symbol" aria-hidden="true">
        <UiIcon name="warning" />
      </span>
      <h2 id="confirmation-title">{title}</h2>
      <div className="dialog-content">{children}</div>
      <div className="dialog-buttons">
        <button
          className="menu-secondary"
          disabled={busy}
          autoFocus
          onClick={onCancel}
        >
          Abbrechen
        </button>
        <button className="menu-primary" disabled={busy} onClick={onAccept}>
          {busy ? "Bitte warten …" : accept}
        </button>
      </div>
    </dialog>
  );
}

export function Settings({
  data,
  onClosed,
}: {
  data: BindingPayload;
  onClosed: () => void;
}) {
  const [bindings, setBindings] = useState(data);
  const [selected, setSelected] = useState(data.actions[0]?.id ?? "");
  const [query, setQuery] = useState("");
  const [category, setCategory] = useState("Alle Aktionen");
  const [rebinding, setRebinding] = useState(false);
  const [confirmation, setConfirmation] = useState<Confirmation | null>(null);
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState("Änderungen werden sofort gespeichert.");
  const action = bindings.actions.find((a) => a.id === selected);
  const missing = bindings.actions.filter((a) => !a.key);
  const keyLabel = (id: string) =>
    bindings.keys.find((k) => k.id === id)?.label ?? "Nicht belegt";
  const affected = (id: string) => bindings.actions.filter((a) => a.key === id);
  const categories = [
    "Alle Aktionen",
    ...new Set(bindings.actions.map((a) => a.category)),
    "Nicht belegt",
  ];
  const filtered = bindings.actions.filter(
    (a) =>
      (category === "Alle Aktionen" ||
        a.category === category ||
        (category === "Nicht belegt" && !a.key)) &&
      `${a.label} ${a.category} ${keyLabel(a.key)}`
        .toLocaleLowerCase("de")
        .includes(query.toLocaleLowerCase("de")),
  );
  useEffect(() => {
    document
      .getElementById(`action-${selected}`)
      ?.scrollIntoView({ block: "nearest" });
  }, [selected, query, category]);
  const commit = (next: BindingPayload) => {
    setBindings(next);
    if (isBrowser())
      localStorage.setItem("rp-input-preview", JSON.stringify(next));
  };
  const bind = async (key: string, confirmed = false) => {
    if (!action || busy) return;
    setBusy(true);
    try {
      if (isBrowser()) {
        commit({
          ...bindings,
          revision: bindings.revision + 1,
          actions: bindings.actions.map((a) => ({
            ...a,
            key:
              a.id === action.id
                ? key
                : key !== "" && a.key === key && action.key !== key
                  ? ""
                  : a.key,
          })),
        });
      } else {
        const result = await fetchNui("rp_ui:bind", {
          action: action.id,
          key,
          confirmed,
          revision: bindings.revision,
        });
        if (result.bindings) commit(result.bindings);
        if (!result.ok) {
          setStatus(errorLabel(result.error));
          setConfirmation(null);
          return;
        }
      }
      setStatus(
        key
          ? `${action.label} ist jetzt auf ${keyLabel(key)} belegt.`
          : `${action.label} hat jetzt keine Taste.`,
      );
      setRebinding(false);
      setConfirmation(null);
    } catch {
      setStatus(
        "Speichern fehlgeschlagen. Deine bisherige Belegung bleibt sichtbar.",
      );
    } finally {
      setBusy(false);
    }
  };
  const selectKey = (key: InputKey) => {
    if (busy || key.reserved) return;
    const linked = affected(key.id);
    if (rebinding && action) {
      const conflicts = linked.filter((a) => a.id !== action.id);
      if (conflicts.length && key.id !== action.key)
        setConfirmation({
          kind: "replace",
          key,
          names: conflicts.map((a) => a.label),
        });
      else void bind(key.id);
    } else if (linked.length) {
      setQuery("");
      setCategory("Alle Aktionen");
      const index = linked.findIndex((a) => a.id === selected);
      setSelected(linked[(index + 1) % linked.length].id);
    } else
      setStatus(
        `${key.label} ist frei. Wähle links eine Aktion und dann „Neu belegen“.`,
      );
  };
  const close = async (confirmed = false) => {
    if (busy) return;
    if (missing.length && !confirmed) {
      setConfirmation({ kind: "close" });
      return;
    }
    setBusy(true);
    try {
      const result = await fetchNui("rp_ui:closeSettings", {
        confirmed,
        revision: bindings.revision,
      });
      if (result.bindings) commit(result.bindings);
      if (result.ok) onClosed();
      else {
        setStatus(errorLabel(result.error));
        setConfirmation(null);
      }
    } catch {
      setStatus(
        "Das Menü konnte gerade nicht geschlossen werden. Bitte erneut versuchen.",
      );
    } finally {
      setBusy(false);
    }
  };
  const reset = async () => {
    setBusy(true);
    try {
      if (isBrowser())
        commit({
          ...bindings,
          revision: bindings.revision + 1,
          actions: bindings.actions.map((a) => ({ ...a, key: a.defaultKey })),
        });
      else {
        const result = await fetchNui("rp_ui:resetBindings", {
          revision: bindings.revision,
        });
        if (result.bindings) commit(result.bindings);
        if (!result.ok) {
          setStatus(errorLabel(result.error));
          setConfirmation(null);
          return;
        }
      }
      setStatus("Standardbelegung wiederhergestellt.");
      setConfirmation(null);
      setRebinding(false);
    } catch {
      setStatus("Zurücksetzen fehlgeschlagen. Bitte erneut versuchen.");
    } finally {
      setBusy(false);
    }
  };
  const requestClose = () => {
    if (rebinding) {
      setRebinding(false);
      setStatus("Neubelegung abgebrochen.");
    } else void close();
  };
  useMenuToggle(bindings.actions.find((a) => a.id === "rp_ui:settings")?.key,
    requestClose, !!confirmation || busy);
  useEffect(() => {
    const keydown = (e: KeyboardEvent) => {
      if (confirmation || e.repeat || busy || e.defaultPrevented) return;
      if (e.key === "Escape") {
        e.preventDefault();
        requestClose();
      }
    };
    window.addEventListener("keydown", keydown);
    return () => window.removeEventListener("keydown", keydown);
  });
  const keyButton = (key: InputKey) => {
    const linked = affected(key.id);
    const occupied = linked.length > 0;
    const active = action?.key === key.id;
    const state = rebinding
      ? occupied
        ? "key-occupied"
        : "key-free"
      : occupied
        ? "key-bound"
        : "";
    return (
      <button
        key={key.id}
        data-key={key.id}
        className={`keyboard-key ${key.reserved ? "key-reserved" : state} ${active ? "key-selected" : ""}`}
        style={{ "--key-width": key.width } as CSSProperties}
        disabled={key.reserved || busy}
        aria-pressed={active}
        aria-label={`${key.label}${key.reserved ? " · reserviert" : linked.length ? ` · ${linked.map((a) => a.label).join(", ")}` : " · frei"}`}
        title={
          key.reserved
            ? "Für das System reserviert"
            : linked.map((a) => a.label).join(" · ") || "Frei"
        }
        onClick={() => selectKey(key)}
      >
        <span>{key.label}</span>
        {occupied && !key.reserved && (
          <i aria-hidden="true">{linked.length > 1 ? linked.length : "•"}</i>
        )}
      </button>
    );
  };
  return (
    <div className="menu-backdrop">
      <main className="settings menu-shell" aria-label="Einstellungen">
        <header className="menu-header">
          <div>
            <p className="menu-kicker">DEIN SPIEL. DEINE STEUERUNG.</p>
            <div className="ui-title">
              <UiIcon name="settings" />
              <h1>
                Einstellungen<span>.</span>
              </h1>
            </div>
          </div>
          <div className="header-right">
            <span className="status-pill">LOKALES PROFIL</span>
            <button
              className="menu-close"
              aria-label="Einstellungen schließen"
              disabled={busy}
              onClick={() => void close()}
            >
              <UiIcon name="close" />
            </button>
          </div>
        </header>
        <div className="settings-section">
          <span className="active-section ui-inline">
            <UiIcon name="keyboard" />
            Tastenbelegung
          </span>
          <span>Deine eigenen Spielaktionen</span>
        </div>
        <div className="bindings-layout">
          <aside className="actions-panel">
            <div className="action-search">
              <label htmlFor="action-search">AKTION FINDEN</label>
              <input
                id="action-search"
                placeholder="Suchen …"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
              />
              <select
                aria-label="Kategorie"
                value={category}
                onChange={(e) => setCategory(e.target.value)}
              >
                {categories.map((c) => (
                  <option key={c}>{c}</option>
                ))}
              </select>
            </div>
            <div className="action-list" aria-label="Eigene Spielaktionen">
              {filtered.map((a) => (
                <button
                  id={`action-${a.id}`}
                  data-action={a.id}
                  key={a.id}
                  className={`action-row ${a.id === selected ? "action-selected" : ""} ${a.key && a.key === action?.key ? "action-linked" : ""}`}
                  aria-pressed={a.id === selected}
                  disabled={busy}
                  onClick={() => {
                    setSelected(a.id);
                    setRebinding(false);
                  }}
                >
                  <UiIcon
                    name={
                      a.id === "rp_inventory:open"
                        ? "bag"
                        : a.id === "rp_player:me"
                          ? "person"
                          : "settings"
                    }
                  />
                  <span>
                    <strong>{a.label}</strong>
                    <small>
                      {a.category} · {contextLabels[a.context] ?? "Überall"}
                    </small>
                  </span>
                  <kbd className={!a.key ? "unbound" : ""}>
                    {keyLabel(a.key)}
                  </kbd>
                </button>
              ))}
              {!filtered.length && (
                <p className="no-actions">Keine passende Aktion gefunden.</p>
              )}
            </div>
            <div className="action-count">
              {bindings.actions.length} Aktionen
              <span>
                {missing.length
                  ? `${missing.length} ohne Taste`
                  : "Alles belegt"}
              </span>
            </div>
          </aside>
          <section className="keyboard-panel">
            <div className="keyboard-heading">
              <div>
                <p className="menu-kicker">TASTATUR & MAUS</p>
                <h2>
                  {rebinding
                    ? "Wähle deine neue Taste"
                    : "Alles an seinem Platz"}
                </h2>
              </div>
              <span className="layout-label">DE · QWERTZ</span>
            </div>
            <p className="keyboard-help">
              {rebinding
                ? `Neue Taste für „${action?.label}“ anklicken. Belegte Tasten benötigen deine Bestätigung.`
                : "Wähle eine Aktion oder eine belegte Taste. Bei mehreren Aktionen wechselt ein weiterer Klick zur nächsten."}
            </p>
            <div
              className={`keyboard ${rebinding ? "is-rebinding" : ""}`}
              aria-label="Virtuelle Tastatur"
            >
              {[0, 1, 2, 3, 4, 5].map((row) => (
                <div className={`keyboard-row keyboard-row-${row}`} key={row}>
                  {bindings.keys.filter((k) => k.row === row).map(keyButton)}
                </div>
              ))}
            </div>
            <div className="extra-keys">
              <div>
                <p>NAVIGATION</p>
                <div className="extra-key-grid">
                  {bindings.keys.filter((k) => k.row === 6).map(keyButton)}
                </div>
              </div>
              <div>
                <p>NUMMERNBLOCK</p>
                <div className="extra-key-grid">
                  {bindings.keys.filter((k) => k.row === 7).map(keyButton)}
                </div>
              </div>
              <div>
                <p>MAUS</p>
                <div className="extra-key-grid mouse-key-grid">
                  {bindings.keys.filter((k) => k.row === 8).map(keyButton)}
                </div>
              </div>
            </div>
            <div className="keyboard-legend">
              <span>
                <i className={rebinding ? "legend-free" : "legend-bound"} />
                {rebinding ? "Frei · direkt belegen" : "Belegt"}
              </span>
              <span>
                <i
                  className={rebinding ? "legend-occupied" : "legend-selected"}
                />
                {rebinding ? "Belegt · überschreiben" : "Ausgewählte Aktion"}
              </span>
              <span>
                <i className="legend-reserved" />
                Systemtaste
              </span>
            </div>
            {action && (
              <div
                className={`binding-detail ${rebinding ? "binding-editing" : ""}`}
              >
                <div>
                  <p className="menu-kicker">
                    {rebinding ? "NEUBELEGUNG AKTIV" : "AUSGEWÄHLTE AKTION"}
                  </p>
                  <h3>
                    {action.label} <kbd>{keyLabel(action.key)}</kbd>
                  </h3>
                  <p>{action.description}</p>
                </div>
                <div className="binding-detail-buttons">
                  <button
                    className="menu-primary"
                    disabled={busy}
                    onClick={() => setRebinding(!rebinding)}
                  >
                    {rebinding ? "Abbrechen" : "Neu belegen"}{" "}
                    <UiIcon name={rebinding ? "close" : "keyboard"} />
                  </button>
                  {action.key && (
                    <button
                      className="text-button"
                      disabled={busy}
                      onClick={() => void bind("")}
                    >
                      Belegung entfernen
                    </button>
                  )}
                </div>
              </div>
            )}
            <p className="system-note">
              Hier belegst du ausschließlich eigene Systeme. GTA-Funktionen wie
              Laufen oder Fahren bleiben in den GTA-Einstellungen. Escape, F8
              und Windows-Tasten sind reserviert.
            </p>
          </section>
        </div>
        <footer className="menu-footer">
          <span role="status">{status}</span>
          <button
            className="text-button"
            disabled={busy}
            onClick={() => setConfirmation({ kind: "reset" })}
          >
            Standard wiederherstellen
          </button>
          <span className="close-hint">
            <kbd>Esc</kbd> Zurück ins Spiel
          </span>
        </footer>
        {confirmation && (
          <Confirm
            busy={busy}
            title={
              confirmation.kind === "replace"
                ? "Belegte Taste überschreiben?"
                : confirmation.kind === "close"
                  ? "Aktionen ohne Taste"
                  : "Standard wiederherstellen?"
            }
            accept={
              confirmation.kind === "replace"
                ? "Überschreiben & belegen"
                : confirmation.kind === "close"
                  ? "Trotzdem schließen"
                  : "Wiederherstellen"
            }
            onCancel={() => setConfirmation(null)}
            onAccept={() => {
              if (confirmation.kind === "replace")
                void bind(confirmation.key.id, true);
              else if (confirmation.kind === "close") void close(true);
              else void reset();
            }}
          >
            {confirmation.kind === "replace" ? (
              <>
                <p>
                  <strong>{confirmation.key.label}</strong> wird neu für{" "}
                  <strong>{action?.label}</strong> belegt. Diese bisherigen
                  Aktionen verlieren ihre Taste und müssen anschließend neu
                  belegt werden:
                </p>
                <ul>
                  {confirmation.names.map((n) => (
                    <li key={n}>{n}</li>
                  ))}
                </ul>
              </>
            ) : confirmation.kind === "close" ? (
              <>
                <p>
                  Diese Aktionen haben keine Taste. Du kannst sie erst nach
                  einer neuen Belegung wieder über eine Taste ausführen:
                </p>
                <ul>
                  {missing.map((a) => (
                    <li key={a.id}>{a.label}</li>
                  ))}
                </ul>
                <p>
                  Einstellungen erreichst du bei Bedarf in der F8-Konsole mit{" "}
                  <strong>rp_settings</strong>.
                </p>
              </>
            ) : (
              <p>
                Deine Änderungen werden durch die Standardbelegung ersetzt.
                Gemeinsam genutzte Tasten erhalten wieder alle ursprünglichen
                Aktionen.
              </p>
            )}
          </Confirm>
        )}
      </main>
    </div>
  );
}
