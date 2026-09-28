import { useState } from "react";
import { UiIcon } from "../components/UiIcon";
import {
  errorLabel,
  fetchNui,
  isBrowser,
  type ProfilePayload,
} from "../lib/nui";

const number = new Intl.NumberFormat("de-DE");
const money = new Intl.NumberFormat("de-DE", {
  style: "currency",
  currency: "USD",
  maximumFractionDigits: 0,
});
export function Me({
  data,
  onClose,
  onOrganizations,
}: {
  data: ProfilePayload;
  onClose: () => void;
  onOrganizations: () => void;
}) {
  const [profile, setProfile] = useState(data);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const maxed = profile.level >= profile.maxLevel;
  const progress = maxed
    ? 100
    : Math.min(
        100,
        ((profile.runningMeters % profile.metersPerLevel) /
          profile.metersPerLevel) *
          100,
      );
  const remaining =
    profile.metersPerLevel - (profile.runningMeters % profile.metersPerLevel);
  const refresh = async () => {
    setBusy(true);
    setError("");
    try {
      const result = await fetchNui("rp_player:refresh");
      if (result.ok && result.profile) setProfile(result.profile);
      else if (!isBrowser()) setError(errorLabel(result.error));
    } catch {
      setError("Deine Übersicht konnte nicht aktualisiert werden.");
    } finally {
      setBusy(false);
    }
  };
  const organizations = async () => {
    if (isBrowser()) {
      onOrganizations();
      return;
    }
    setBusy(true);
    setError("");
    try {
      const result = await fetchNui("rp_organizations:open");
      if (!result.ok) setError(errorLabel(result.error));
    } catch {
      setError("Die Organisationsverwaltung ist gerade nicht erreichbar.");
    } finally {
      setBusy(false);
    }
  };
  return (
    <div className="menu-backdrop">
      <main className="personal menu-shell" aria-label="Mein Charakter">
        <header className="menu-header">
          <div>
            <p className="menu-kicker">LOS SANTOS · DEIN LEBEN</p>
            <div className="ui-title">
              <UiIcon name="person" />
              <h1>
                Mein Charakter<span>.</span>
              </h1>
            </div>
          </div>
          <button
            className="menu-close"
            aria-label="Menü schließen"
            onClick={onClose}
          >
            <UiIcon name="close" />
          </button>
        </header>
        <div className="personal-grid">
          <section className="identity-panel">
            <div className="identity-monogram" aria-hidden="true">
              {profile.name
                .split(" ")
                .map((s) => s[0])
                .slice(0, 2)
                .join("")}
            </div>
            <span className="status-pill">BÜRGER VON LOS SANTOS</span>
            <h2>{profile.name}</h2>
            <p className="identity-job">
              {profile.job} <span>· {profile.grade}</span>
            </p>
            <dl className="identity-facts">
              <div>
                <dt className="ui-inline">
                  <UiIcon name="calendar" />
                  Geburtsdatum
                </dt>
                <dd>{profile.birthdate || "—"}</dd>
              </div>
              <div>
                <dt className="ui-inline">
                  <UiIcon name="ruler" />
                  Körpergröße
                </dt>
                <dd>{profile.height} cm</dd>
              </div>
            </dl>
            <div className="balance">
              <span className="ui-inline">
                <UiIcon name="wallet" />
                Bargeld
              </span>
              <strong>{money.format(profile.cash)}</strong>
            </div>
            <div className="balance">
              <span className="ui-inline">
                <UiIcon name="bank" />
                Bankkonto
              </span>
              <strong>{money.format(profile.bank)}</strong>
            </div>
          </section>
          <section className="fitness-panel">
            <div className="section-heading">
              <div>
                <p className="menu-kicker">MIT JEDEM SCHRITT WEITER</p>
                <h2>Fitness & Ausdauer</h2>
              </div>
              <span className="fitness-symbol" aria-hidden="true">
                <UiIcon name="fitness" />
              </span>
            </div>
            <div className="fitness-level">
              <span className="level-number">
                {String(profile.level).padStart(2, "0")}
              </span>
              <div>
                <span className="status-pill">AUSDAUERLEVEL</span>
                <p>Dein Fortschritt bleibt bei dir.</p>
              </div>
              <span className="level-max">/ {profile.maxLevel}</span>
            </div>
            <div className="progress-label">
              <strong>
                {maxed
                  ? "Maximum erreicht"
                  : `Auf dem Weg zu Level ${profile.level + 1}`}
              </strong>
              <span>
                {maxed
                  ? "100 %"
                  : `Noch ${number.format(Math.ceil(remaining))} m`}
              </span>
            </div>
            <div
              className="fitness-track"
              role="progressbar"
              aria-label="Fortschritt zum nächsten Level"
              aria-valuenow={Math.round(progress)}
              aria-valuemin={0}
              aria-valuemax={100}
            >
              <i style={{ width: `${progress}%` }} />
            </div>
            <div className="fitness-stats">
              <article>
                <span className="ui-inline">
                  <UiIcon name="fitness" />
                  Gelaufene Strecke
                </span>
                <strong>
                  {number.format(Math.round(profile.runningMeters / 10) / 100)}{" "}
                  <small>km</small>
                </strong>
              </article>
              <article>
                <span className="ui-inline">
                  <UiIcon name="clock" />
                  Aktive Trainingszeit
                </span>
                <strong>
                  {Math.floor(profile.trainingSeconds / 60)} <small>min</small>
                </strong>
              </article>
            </div>
            <div className="stamina-row">
              <div>
                <strong>Aktuelle Ausdauer</strong>
                <p>Deine Energie im Moment</p>
              </div>
              <span>
                {Math.round(Math.max(0, Math.min(100, profile.stamina)))} %
              </span>
            </div>
            <div className="fitness-track stamina-track">
              <i
                style={{
                  width: `${Math.max(0, Math.min(100, profile.stamina))}%`,
                }}
              />
            </div>
            <div className="training-note">
              <UiIcon name="fitness" />
              <p>
                <strong>Rausgehen. Laufen. Besser werden.</strong> Joggen und
                Sprinten verbessern deine Ausdauer. Je{" "}
                {number.format(profile.metersPerLevel)} gelaufene Meter steigst
                du ein Level auf.
              </p>
            </div>
          </section>
        </div>
        <footer className="menu-footer">
          <button
            className="menu-secondary"
            disabled={busy}
            onClick={() => void organizations()}
          >
            <UiIcon name="organization" />
            Organisationen <UiIcon name="arrow" />
          </button>
          <span role="status">
            {error || "Deine Werte werden pro Charakter gespeichert."}
          </span>
          <button
            className="menu-secondary"
            disabled={busy}
            onClick={() => void refresh()}
          >
            {busy ? "Lädt …" : "Werte aktualisieren"} <UiIcon name="refresh" />
          </button>
        </footer>
      </main>
    </div>
  );
}
