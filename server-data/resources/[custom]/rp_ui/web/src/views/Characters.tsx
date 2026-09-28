import { useEffect, useRef, useState } from "react";
import { UiIcon } from "../components/UiIcon";
import {
  errorLabel,
  fetchNui,
  isBrowser,
  type AppearanceField,
  type CharacterPayload,
  type FieldGroup,
  type Skin,
} from "../lib/nui";

import { CreatorCamera, type CameraView } from "./CreatorCamera";
import { previewChange } from "../lib/preview";
import { CreatorIcon, type CreatorIconName } from "./CreatorIcon";

type Tab = "identity" | FieldGroup;
const tabs: { id: Tab; label: string; short: string; icon: CreatorIconName }[] =
  [
    { id: "identity", label: "Identität", short: "01", icon: "identity" },
    { id: "heritage", label: "Herkunft", short: "02", icon: "heritage" },
    { id: "face", label: "Gesicht", short: "03", icon: "face" },
    { id: "hair", label: "Haare", short: "04", icon: "hair" },
    { id: "skin", label: "Details", short: "05", icon: "details" },
    { id: "clothes", label: "Kleidung", short: "06", icon: "upper" },
    {
      id: "accessories",
      label: "Accessoires",
      short: "07",
      icon: "accessories",
    },
  ];
const subtitles: Record<Tab, string> = {
  identity: "Der erste Eintrag in deiner neuen Geschichte.",
  heritage: "Eine Mischung, die nur dir gehört.",
  face: "Kleine Details. Ein unverwechselbares Gesicht.",
  hair: "Finde deinen eigenen Look.",
  skin: "Die Details machen den Unterschied.",
  clothes: "Dein erster Auftritt in Los Santos.",
  accessories: "Gib deinem Look den letzten Schliff.",
};

export function Characters({ data }: { data: CharacterPayload }) {
  const [mode, setMode] = useState(data.mode);
  const [tab, setTab] = useState<Tab>("identity");
  const [skin, setSkin] = useState<Skin>(data.skin);
  const [fields, setFields] = useState(data.fields);
  const [selected, setSelected] = useState(data.characters[0]?.slot ?? 1);
  const [identity, setIdentity] = useState({
    firstname: "",
    lastname: "",
    dateofbirth: "",
    height: "180",
  });
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [editing, setEditing] = useState(false);
  const [cameraFocus, setCameraFocus] = useState<CameraView>("body");
  const [modelChanging, setModelChanging] = useState(false);
  const [search, setSearch] = useState("");
  const [previewOnly, setPreviewOnly] = useState(false);
  const queue = useRef(new Map<string, number>());
  const draining = useRef(false);
  const mounted = useRef(true);
  const form = useRef<HTMLFormElement>(null);
  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
    };
  }, []);
  useEffect(() => {
    setMode(data.mode);
    setSkin(data.skin);
    setFields(data.fields);
    setError(data.error ? errorLabel(data.error) : "");
  }, [data]);
  const action = async (
    name: string,
    payload: Record<string, unknown> = {},
    success?: () => void,
  ) => {
    if (busy) return;
    setBusy(true);
    setError("");
    try {
      const response = await fetchNui(`rp_characters:${name}`, payload);
      if (!response.ok) setError(errorLabel(response.error));
      else success?.();
    } catch {
      setError("Verbindung unterbrochen. Bitte erneut versuchen.");
    } finally {
      setBusy(false);
    }
  };
  const change = (key: string, value: number) => {
    if (key === "sex") {
      queue.current.clear();
      setModelChanging(true);
    }
    setSkin((current) => ({ ...current, [key]: value }));
    queue.current.set(key, value);
    if (draining.current) return;
    draining.current = true;
    setEditing(true);
    void (async () => {
      try {
        while (queue.current.size && mounted.current) {
          const next = queue.current.entries().next().value;
          if (!next) break;
          queue.current.delete(next[0]);
          const payload = {
            key: next[0],
            value: next[1],
          };
          const result = isBrowser()
            ? previewChange(payload)
            : await fetchNui("rp_characters:appearance", payload);
          if (!result.ok) {
            setError(errorLabel(result.error));
            queue.current.clear();
            break;
          }
          if (result.skin) {
            const update = { ...result.skin };
            queue.current.forEach((v, k) => {
              update[k] = v;
            });
            setSkin(update);
          }
          if (result.fields) setFields(result.fields);
        }
      } catch {
        setError("Die Vorschau konnte nicht aktualisiert werden.");
        queue.current.clear();
      } finally {
        draining.current = false;
        if (mounted.current) {
          setEditing(false);
          setModelChanging(false);
        }
      }
    })();
  };
  const navigate = (next: Tab) => {
    setTab(next);
    setSearch("");
    setCameraFocus(
      ["heritage", "face", "hair", "skin"].includes(next) ? "face" : "body",
    );
  };
  const currentCharacter = data.characters.find(
    (character) => character.slot === selected,
  );
  const visibleFields = fields.filter(
    (field) =>
      field.group === tab &&
      field.key !== "sex" &&
      field.max > field.min &&
      field.label
        .toLocaleLowerCase("de")
        .includes(search.toLocaleLowerCase("de")),
  );
  const updateIdentity = (key: keyof typeof identity, value: string) =>
    setIdentity((current) => ({ ...current, [key]: value }));
  const today = new Date();
  const dateBound = (age: number) => {
    const d = new Date(
      Date.UTC(today.getFullYear() - age, today.getMonth(), today.getDate()),
    );
    return d.toISOString().slice(0, 10);
  };
  const create = () => {
    if (!identity.firstname || !identity.lastname || !identity.dateofbirth) {
      setTab("identity");
      setError("Bitte vervollständige zuerst deine Identität.");
      return;
    }
    if (tab === "identity" && !form.current?.reportValidity()) return;
    void action(
      "create",
      { ...identity, height: Number(identity.height) },
      () => {
        if (isBrowser()) setMode("loading");
      },
    );
  };

  return (
    <main
      className={`character-shell mode-${mode} ${isBrowser() ? "browser-scene" : ""} ${previewOnly ? "preview-only" : ""}`}
    >
      <header className="brandbar">
        <div className="airport-mark" aria-hidden="true">
          ↗
        </div>
        <div>
          <strong>LOS SANTOS</strong>
          <span>
            {mode === "creator" ? "CHARACTER STUDIO" : "INTERNATIONAL AIRPORT"}
          </span>
        </div>
        <div className="connection">
          <i /> {mode === "creator" ? "DEIN NEUER ANFANG" : "EINREISEPORTAL"}{" "}
          <span> / LS</span>
        </div>
      </header>
      <div className="scene-caption">
        <span>LOS SANTOS, SAN ANDREAS</span>
        <span>33°56′ N &nbsp; 118°24′ W</span>
      </div>
      {mode === "selection" && (
        <>
          <section className="selection-intro">
            <p className="eyebrow">DEIN NÄCHSTES KAPITEL</p>
            <h1>
              Willkommen
              <br />
              <em>zurück.</em>
            </h1>
            <p>
              Eine Stadt. Unzählige Geschichten.
              <br />
              Mit welcher setzt du deine fort?
            </p>
          </section>
          <section className="roster" aria-label="Charakterauswahl">
            <div className="section-heading">
              <span>DEINE CHARAKTERE</span>
              <span>
                {data.characters.length} / {data.slots} PLÄTZE BELEGT
              </span>
            </div>
            <div className="character-cards">
              {Array.from({ length: data.slots }, (_, index) => {
                const slot = index + 1;
                const character = data.characters.find(
                  (item) => item.slot === slot,
                );
                return character ? (
                  <button
                    key={slot}
                    className={`character-card ${selected === slot ? "selected" : ""}`}
                    aria-pressed={selected === slot}
                    disabled={busy}
                    onClick={() =>
                      void action("preview", { slot }, () => setSelected(slot))
                    }
                  >
                    <div className="card-top">
                      <span>CHARAKTER {String(slot).padStart(2, "0")}</span>
                      <span className="selection-dot">
                        <UiIcon name={selected === slot ? "check" : "person"} />
                      </span>
                    </div>
                    <span className="card-initials">
                      {character.firstname.charAt(0)}
                      {character.lastname.charAt(0)}
                    </span>
                    <strong>
                      {character.firstname}
                      <br />
                      {character.lastname}
                    </strong>
                    <span className="job-label">{character.job}</span>
                    <div className="card-bottom">
                      <span>{character.dateofbirth}</span>
                      <span>{character.height} CM</span>
                    </div>
                  </button>
                ) : (
                  <button
                    key={slot}
                    className="character-card empty-card"
                    disabled={busy || data.characters.length >= data.slots}
                    onClick={() =>
                      void action("new", {}, () => {
                        if (isBrowser()) setMode("creator");
                        setTab("identity");
                      })
                    }
                  >
                    <span className="card-top">
                      FREIER PLATZ {String(slot).padStart(2, "0")}
                    </span>
                    <span className="plus">
                      <UiIcon name="plus" />
                    </span>
                    <strong>Neue Geschichte</strong>
                    <span>Charakter erstellen</span>
                  </button>
                );
              })}
            </div>
            <div className="roster-footer">
              <span>Letzter Standort · Dein Fortschritt wartet auf dich</span>
              <button
                className="primary"
                disabled={busy || !currentCharacter}
                onClick={() =>
                  void action("select", { slot: selected }, () => {
                    if (isBrowser()) setMode("loading");
                  })
                }
              >
                {busy ? "Wird geladen …" : "Geschichte fortsetzen"}{" "}
                <UiIcon name="arrow" />
              </button>
            </div>
          </section>
        </>
      )}
      {mode === "creator" && (
        <>
          <section className="creator-intro">
            <p className="eyebrow">CHARAKTER ERSTELLEN</p>
            <h1>
              Dein Look. <em>Deine Geschichte.</em>
            </h1>
            <p>
              <CreatorIcon name={skin.sex === 1 ? "female" : "male"} />
              {[identity.firstname, identity.lastname]
                .filter(Boolean)
                .join(" ") || "Eine neue Identität"}
            </p>
          </section>
          <section className="creator-panel" aria-label="Charakter erstellen">
            <div className="panel-top">
              <div>
                <span className="eyebrow">DEIN CHARAKTER</span>
                <h2>
                  <CreatorIcon name={tabs.find((t) => t.id === tab)!.icon} />
                  {tabs.find((t) => t.id === tab)?.label}
                </h2>
              </div>
              <span className="step-number">
                {String(tabs.findIndex((t) => t.id === tab) + 1).padStart(
                  2,
                  "0",
                )}
                <small> / 07</small>
              </span>
            </div>
            <nav className="creator-tabs" aria-label="Creator-Bereiche">
              {tabs.map((item) => (
                <button
                  type="button"
                  key={item.id}
                  className={tab === item.id ? "active" : ""}
                  aria-label={`${item.short} ${item.label}`}
                  aria-pressed={tab === item.id}
                  data-tip={item.label}
                  onClick={() => navigate(item.id)}
                  disabled={busy}
                >
                  <CreatorIcon name={item.icon} />
                </button>
              ))}
            </nav>
            <div className="editor-scroll">
              <div className="editor-heading">
                <p>{subtitles[tab]}</p>
                {tab === "clothes" && (
                  <p className="wardrobe-note">
                    Je 12 Anreise-Looks · Oberteil, Hose & Schuhe
                  </p>
                )}
              </div>
              {tab === "identity" ? (
                <form
                  ref={form}
                  className="identity-form"
                  onSubmit={(e) => {
                    e.preventDefault();
                    navigate("heritage");
                  }}
                >
                  <div className="input-pair">
                    <label>
                      Vorname
                      <input
                        autoComplete="off"
                        value={identity.firstname}
                        onChange={(e) =>
                          updateIdentity("firstname", e.target.value)
                        }
                        placeholder="Alex"
                        minLength={2}
                        maxLength={16}
                        required
                      />
                    </label>
                    <label>
                      Nachname
                      <input
                        autoComplete="off"
                        value={identity.lastname}
                        onChange={(e) =>
                          updateIdentity("lastname", e.target.value)
                        }
                        placeholder="Morgan"
                        minLength={2}
                        maxLength={16}
                        required
                      />
                    </label>
                  </div>
                  <label>
                    Geburtsdatum
                    <input
                      type="date"
                      value={identity.dateofbirth}
                      min={dateBound(data.maxAge + 1)}
                      max={dateBound(data.minAge)}
                      onChange={(e) =>
                        updateIdentity("dateofbirth", e.target.value)
                      }
                      required
                    />
                    <small>
                      {data.minAge} bis {data.maxAge} Jahre
                    </small>
                  </label>
                  <label>
                    Körpergröße
                    <div className="unit-input">
                      <input
                        type="number"
                        min={120}
                        max={230}
                        step={1}
                        value={identity.height}
                        onChange={(e) =>
                          updateIdentity("height", e.target.value)
                        }
                        required
                      />
                      <span>cm</span>
                    </div>
                  </label>
                  <fieldset>
                    <legend>Körpermodell</legend>
                    <div className="model-options">
                      <button
                        type="button"
                        className={skin.sex === 0 ? "active" : ""}
                        disabled={editing}
                        onClick={() => change("sex", 0)}
                      >
                        <CreatorIcon name="male" /> Männlich
                      </button>
                      <button
                        type="button"
                        className={skin.sex === 1 ? "active" : ""}
                        disabled={editing}
                        onClick={() => change("sex", 1)}
                      >
                        <CreatorIcon name="female" /> Weiblich
                      </button>
                    </div>
                    <small>Ein Modellwechsel setzt das Aussehen zurück.</small>
                  </fieldset>
                  <div className="identity-note">
                    <span>↗</span>
                    <p>
                      Mit deiner Registrierung beginnt dein Leben in Los Santos.
                      Nimm dir Zeit für deinen Charakter.
                    </p>
                  </div>
                </form>
              ) : (
                <>
                  <label className="search-field">
                    <CreatorIcon name="search" />
                    <input
                      aria-label="Einstellungen durchsuchen"
                      value={search}
                      onChange={(e) => setSearch(e.target.value)}
                      placeholder="Detail finden …"
                    />
                  </label>
                  <div className="appearance-controls" key={tab}>
                    {[
                      ...new Set(
                        visibleFields.map(
                          (field) => field.section ?? "Einstellungen",
                        ),
                      ),
                    ].map((section, index) => (
                      <details
                        className="appearance-section"
                        key={section}
                        open={search ? true : undefined}
                        ref={(node) => {
                          if (node && !node.dataset.initialized) {
                            node.open = index === 0 || !!search;
                            node.dataset.initialized = "true";
                          }
                        }}
                        onToggle={(event) => {
                          if (!event.currentTarget.open) return;
                          if (section === "Schuhe") setCameraFocus("shoes");
                          else if (section === "Hosen & Unterteile")
                            setCameraFocus("lower");
                          else if (
                            section === "Oberteile" ||
                            section === "Körperbehaarung" ||
                            section === "Körpermerkmale"
                          )
                            setCameraFocus("upper");
                        }}
                      >
                        <summary>
                          <CreatorIcon
                            name={
                              section === "Schuhe"
                                ? "shoes"
                                : section === "Hosen & Unterteile"
                                  ? "lower"
                                  : section === "Oberteile"
                                    ? "upper"
                                    : tabs.find((t) => t.id === tab)!.icon
                            }
                          />
                          {section}
                          <span>
                            {String(
                              visibleFields.filter(
                                (field) =>
                                  (field.section ?? "Einstellungen") ===
                                  section,
                              ).length,
                            ).padStart(2, "0")}
                          </span>
                        </summary>
                        {visibleFields
                          .filter(
                            (field) =>
                              (field.section ?? "Einstellungen") === section,
                          )
                          .map((field) => (
                            <AppearanceControl
                              key={field.key}
                              field={field}
                              value={skin[field.key] ?? field.min}
                              disabled={busy || modelChanging}
                              onChange={(value) => change(field.key, value)}
                            />
                          ))}
                      </details>
                    ))}
                    {!visibleFields.length && (
                      <p className="empty-search">
                        Keine passenden Einstellungen.
                      </p>
                    )}
                  </div>
                </>
              )}
            </div>
            <footer className="editor-footer">
              <div className="progress-track">
                {tabs.map((item) => (
                  <i
                    key={item.id}
                    className={
                      tabs.findIndex((t) => t.id === item.id) <=
                      tabs.findIndex((t) => t.id === tab)
                        ? "filled"
                        : ""
                    }
                  />
                ))}
              </div>
              <div className="editor-buttons">
                <button
                  className="quiet"
                  disabled={
                    busy ||
                    editing ||
                    (tab === "identity" && !data.characters.length)
                  }
                  onClick={() =>
                    tab === "identity"
                      ? void action("back", {}, () => {
                          if (isBrowser()) setMode("selection");
                        })
                      : navigate(
                          tabs[tabs.findIndex((t) => t.id === tab) - 1].id,
                        )
                  }
                >
                  <CreatorIcon name="back" /> Zurück
                </button>
                <button
                  className="primary"
                  disabled={busy || editing}
                  onClick={() => {
                    if (tab === "identity" && !form.current?.reportValidity())
                      return;
                    if (tab === "accessories") create();
                    else
                      navigate(
                        tabs[tabs.findIndex((t) => t.id === tab) + 1].id,
                      );
                  }}
                >
                  {busy
                    ? "Registrierung …"
                    : tab === "accessories"
                      ? "Einreisen"
                      : "Weiter"}{" "}
                  <CreatorIcon name="arrow" />
                </button>
              </div>
            </footer>
          </section>
          <CreatorCamera focus={cameraFocus} onError={setError} />
          <button
            className="creator-preview-toggle"
            aria-label={previewOnly ? "Editor einblenden" : "Editor ausblenden"}
            aria-pressed={previewOnly}
            onClick={() => setPreviewOnly((value) => !value)}
          >
            <CreatorIcon name="eye" />
            <span>{previewOnly ? "Editor einblenden" : "Freie Vorschau"}</span>
          </button>
        </>
      )}
      {(mode === "loading" || mode === "error") && (
        <section className="arrival-status" role="status">
          <div
            className={mode === "loading" ? "boarding-spinner" : "status-icon"}
          >
            <UiIcon name={mode === "error" ? "warning" : "plane"} />
          </div>
          <p className="eyebrow">LOS SANTOS INTERNATIONAL</p>
          <h1>
            {mode === "loading"
              ? "Deine Geschichte wartet."
              : "Einreise unterbrochen."}
          </h1>
          <p>
            {mode === "loading"
              ? "Wir bereiten alles für deine Ankunft vor."
              : error || errorLabel(data.error)}
          </p>
          {mode === "error" && (
            <button
              className="primary"
              disabled={busy}
              onClick={() => void action("refresh")}
            >
              Erneut versuchen ↗
            </button>
          )}
        </section>
      )}
      {error && mode !== "error" && (
        <div className="error-toast" role="alert">
          <UiIcon name="warning" />
          {error}
          <button
            aria-label="Fehlermeldung schließen"
            onClick={() => setError("")}
          >
            <UiIcon name="close" />
          </button>
        </div>
      )}
      <footer className="world-footer">
        <span>LOS SANTOS ROLEPLAY</span>
        <span>YOUR NEXT CHAPTER STARTS HERE.</span>
        <span>LS / SA</span>
      </footer>
    </main>
  );
}

function AppearanceControl({
  field,
  value,
  disabled,
  onChange,
}: {
  field: AppearanceField;
  value: number;
  disabled: boolean;
  onChange: (value: number) => void;
}) {
  const options = field.options;
  const selectedOption =
    options?.findIndex((option) => option.value === value) ?? -1;
  const displayed = options?.[selectedOption]?.label;
  const low = options ? 0 : field.min;
  const high = options ? options.length - 1 : field.max;
  const position = options ? Math.max(0, selectedOption) : value;
  const choose = (next: number) =>
    onChange(options ? options[next].value : next);
  return (
    <div className="appearance-control">
      <div className="control-heading">
        <label htmlFor={`field-${field.key}`}>{field.label}</label>
        <span>
          {displayed ??
            (value === -1 ? "Ohne" : String(value).padStart(2, "0"))}
        </span>
      </div>
      <div className="range-row">
        <button
          aria-label={`${field.label} verringern`}
          disabled={disabled || position <= low}
          onClick={() => choose(position - 1)}
        >
          −
        </button>
        {options ? (
          <select
            id={`field-${field.key}`}
            value={value}
            disabled={disabled || !options.length}
            onChange={(event) => onChange(Number(event.target.value))}
          >
            {options.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        ) : (
          <input
            id={`field-${field.key}`}
            type="range"
            min={field.min}
            max={field.max}
            step={1}
            value={value}
            disabled={disabled || field.min === field.max}
            onChange={(e) => onChange(Number(e.target.value))}
          />
        )}
        <button
          aria-label={`${field.label} erhöhen`}
          disabled={disabled || position >= high}
          onClick={() => choose(position + 1)}
        >
          +
        </button>
      </div>
      <div className="range-labels">
        <span>
          {options ? "AUSWAHL" : field.min === -1 ? "OHNE" : field.min}
        </span>
        <span>
          {options ? `${position + 1} / ${options.length}` : field.max}
        </span>
      </div>
    </div>
  );
}
