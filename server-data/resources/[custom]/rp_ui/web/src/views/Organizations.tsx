import { useEffect, useState } from "react";
import { errorLabel, fetchNui, isBrowser } from "../lib/nui";
import {
  organizationErrors,
  type OrganizationPayload,
  type Organization,
  type OrganizationMember,
} from "../lib/organizations";
import { organizationDemo } from "../lib/organizationPreview";
import { UiIcon } from "../components/UiIcon";

type Command = Record<string, unknown>;
type Dialog = { title: string; text: string; command: Command } | null;
const currency = (value: number) =>
  new Intl.NumberFormat("de-DE", {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: 0,
  }).format(value);
export function Organizations({
  data,
  onClose,
}: {
  data: OrganizationPayload;
  onClose: () => void;
}) {
  const [state, setState] = useState(data);
  const [tab, setTab] = useState("members");
  const [search, setSearch] = useState("");
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState("");
  const [error, setError] = useState("");
  const [dialog, setDialog] = useState<Dialog>(null);
  const [createOpen, setCreateOpen] = useState(false);
  const modalOpen = dialog !== null || createOpen;
  useEffect(() => {
    if (!modalOpen) return;
    const previous = document.activeElement;
    const modal = document.querySelector<HTMLElement>(".organization-modal");
    const focusable = () =>
      Array.from(
        modal?.querySelectorAll<HTMLElement>(
          "button:not(:disabled),input:not(:disabled),select:not(:disabled)",
        ) ?? [],
      );
    focusable()[0]?.focus();
    const listener = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        event.preventDefault();
        event.stopPropagation();
        if (!busy) {
          setDialog(null);
          setCreateOpen(false);
        }
      }
      if (event.key === "Tab") {
        const nodes = focusable(),
          first = nodes[0],
          last = nodes[nodes.length - 1];
        if (event.shiftKey && document.activeElement === first) {
          event.preventDefault();
          last?.focus();
        } else if (!event.shiftKey && document.activeElement === last) {
          event.preventDefault();
          first?.focus();
        }
      }
    };
    window.addEventListener("keydown", listener, true);
    return () => {
      window.removeEventListener("keydown", listener, true);
      if (previous instanceof HTMLElement) previous.focus();
    };
  }, [modalOpen, busy]);
  const selected = state.list.find(
    (o) => `${o.kind}:${o.name}` === state.selected,
  );
  const run = async (command: Command) => {
    if (busy) return;
    setBusy(true);
    setError("");
    setNotice("");
    let refreshed = true;
    try {
      const input = { kind: selected?.kind, name: selected?.name, ...command };
      if (isBrowser()) setState(organizationDemo(state, input));
      else {
        const result = await fetchNui("rp_organizations:request", input);
        if (!result.ok) {
          setError(
            organizationErrors[result.error ?? ""] ?? errorLabel(result.error),
          );
          return;
        }
        if (result.organizations) setState(result.organizations);
        else refreshed = false;
      }
      if (command.action !== "view") {
        setNotice(
          refreshed
            ? "Änderung gespeichert."
            : "Änderung gespeichert. Bitte die Übersicht aktualisieren.",
        );
        setCreateOpen(false);
      }
      setDialog(null);
    } catch {
      setError(
        "Die Verwaltung ist nicht erreichbar. Bitte aktualisieren, bevor du erneut speicherst.",
      );
    } finally {
      setBusy(false);
    }
  };
  const confirm = (title: string, text: string, command: Command) =>
    setDialog({ title, text, command });
  const actorGrade = state.members.find((m) => m.self)?.grade ?? -1;
  const editable = (member: OrganizationMember) =>
    selected?.manage &&
    (state.admin || (!member.self && member.grade < actorGrade)) &&
    (selected.kind === "faction" || member.online);
  return (
    <div className="menu-backdrop">
      <main
        className="organizations menu-shell"
        aria-label="Organisationsverwaltung"
      >
        <header className="menu-header">
          <div>
            <p className="menu-kicker">LOS SANTOS · GEMEINSAM MEHR ERREICHEN</p>
            <div className="ui-title">
              <UiIcon name="organization" />
              <h1>
                Organisationen<span>.</span>
              </h1>
            </div>
          </div>
          <div className="header-right">
            <span className="status-pill">
              {state.admin ? "ADMINISTRATION" : "MEINE ORGANISATIONEN"}
            </span>
            <button
              className="menu-close"
              aria-label="Menü schließen"
              disabled={busy}
              onClick={onClose}
            >
              <UiIcon name="close" />
            </button>
          </div>
        </header>
        <div className="organization-layout">
          <aside className="organization-sidebar">
            <label>
              Organisation finden
              <input
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Suchen …"
              />
            </label>
            <div className="organization-list">
              {(["job", "faction"] as const).map((kind) => (
                <section key={kind}>
                  <p className="menu-kicker">
                    {kind === "job"
                      ? "BERUFE & DIENSTSTELLEN"
                      : "ZUSÄTZLICHE FRAKTIONEN"}
                  </p>
                  {state.list
                    .filter(
                      (o) =>
                        o.kind === kind &&
                        o.label
                          .toLocaleLowerCase("de")
                          .includes(search.toLocaleLowerCase("de")),
                    )
                    .map((org) => (
                      <button
                        key={org.name}
                        className="organization-item"
                        aria-pressed={selected === org}
                        disabled={busy}
                        onClick={() => {
                          setTab("members");
                          void run({
                            action: "view",
                            kind: org.kind,
                            name: org.name,
                          });
                        }}
                      >
                        <span className="organization-icon">
                          <UiIcon
                            name={org.kind === "job" ? "organization" : "team"}
                          />
                        </span>
                        <span>
                          <strong>{org.label}</strong>
                          <small>
                            {org.own
                              ? "Deine Mitgliedschaft"
                              : org.kind === "job"
                                ? "Beruf"
                                : "Fraktion"}
                          </small>
                        </span>
                        <span>›</span>
                      </button>
                    ))}
                </section>
              ))}
            </div>
            {state.admin && (
              <button
                className="menu-secondary"
                disabled={busy}
                onClick={() => setCreateOpen(true)}
              >
                + Organisation anlegen
              </button>
            )}
            <p className="organization-character">
              Aktiver Charakter<strong>{state.character}</strong>
            </p>
          </aside>
          <section className="organization-content">
            {selected ? (
              <>
                <div className="organization-heading">
                  <div>
                    <p className="menu-kicker">
                      {selected.kind === "job" ? "BERUF" : "FRAKTION"} ·{" "}
                      {selected.manage ? "VERWALTUNG" : "ÜBERSICHT"}
                    </p>
                    <h2>{selected.label}</h2>
                    <p>
                      {selected.kind === "job"
                        ? "Dein Beruf, deine Dienststelle und dein Team."
                        : "Diese Mitgliedschaft besteht zusätzlich zu deinem Beruf."}
                    </p>
                  </div>
                  {selected.own &&
                    selected.kind === "job" &&
                    selected.name !== "unemployed" && (
                      <button
                        className="menu-secondary"
                        disabled={busy}
                        onClick={() =>
                          void run({ action: "duty", duty: !selected.duty })
                        }
                      >
                        {selected.duty ? "Dienst beenden" : "Dienst beginnen"}
                      </button>
                    )}
                </div>
                <div className="organization-stats">
                  <article>
                    <span>Mitgliederübersicht</span>
                    <strong>
                      {selected.manage ? state.members.length : "—"}
                    </strong>
                  </article>
                  <article>
                    <span>Ränge</span>
                    <strong>{selected.grades.length}</strong>
                  </article>
                  <article>
                    <span>
                      {selected.kind === "job"
                        ? "Gemeinschaftskonto"
                        : "Mitgliedschaft"}
                    </span>
                    <strong>
                      {selected.kind === "job"
                        ? selected.balance === undefined
                          ? "—"
                          : currency(selected.balance)
                        : selected.own
                          ? "Aktiv"
                          : "Verwaltung"}
                    </strong>
                  </article>
                </div>
                <nav
                  className="organization-tabs"
                  aria-label="Verwaltungsbereiche"
                >
                  {[
                    ["members", "Mitglieder"],
                    ["ranks", "Ränge"],
                    ...(selected.kind === "job" ? [["funds", "Finanzen"]] : []),
                    ...(state.admin ? [["details", "Einstellungen"]] : []),
                  ].map(([id, label]) => (
                    <button
                      key={id}
                      aria-pressed={tab === id}
                      onClick={() => setTab(id)}
                    >
                      <UiIcon
                        name={
                          id === "members"
                            ? "team"
                            : id === "ranks"
                              ? "rank"
                              : id === "funds"
                                ? "bank"
                                : "settings"
                        }
                      />
                      {label}
                    </button>
                  ))}
                </nav>
                <div
                  className="organization-body"
                  key={`${state.selected}:${tab}`}
                >
                  {tab === "members" &&
                    (selected.manage ? (
                      <>
                        <Recruit
                          org={selected}
                          candidates={state.candidates}
                          admin={state.admin}
                          actorGrade={actorGrade}
                          busy={busy}
                          onSubmit={(command) =>
                            confirm(
                              "Mitglied aufnehmen",
                              "Der Charakter erhält die ausgewählte Mitgliedschaft und den Rang.",
                              command,
                            )
                          }
                        />
                        <div className="organization-table-wrap">
                          <table className="organization-table">
                            <thead>
                              <tr>
                                <th>Charakter</th>
                                <th>Rang</th>
                                <th>Status</th>
                                <th>Verwalten</th>
                              </tr>
                            </thead>
                            <tbody>
                              {state.members.map((member) => (
                                <MemberRow
                                  key={member.token}
                                  org={selected}
                                  member={member}
                                  admin={state.admin}
                                  actorGrade={actorGrade}
                                  disabled={busy || !editable(member)}
                                  onCommand={(command, remove) =>
                                    confirm(
                                      remove
                                        ? "Mitglied entfernen"
                                        : "Rang ändern",
                                      remove
                                        ? `${member.name} verliert diese Mitgliedschaft${selected.kind === "job" ? " und wird arbeitslos" : ""}.`
                                        : `Den Rang von ${member.name} ändern?`,
                                      command,
                                    )
                                  }
                                />
                              ))}
                            </tbody>
                          </table>
                        </div>
                        {!state.members.length && (
                          <p className="organization-empty">
                            Noch keine Mitglieder. Nimm den ersten Charakter
                            auf.
                          </p>
                        )}
                        <p className="organization-hint">
                          {selected.kind === "job"
                            ? "Jobänderungen sind für verbundene Charaktere verfügbar. Offline-Mitglieder bleiben sichtbar."
                            : "Fraktionsränge und Mitgliedschaften können auch offline verwaltet werden."}{" "}
                          Die Übersicht zeigt bis zu {state.memberLimit}{" "}
                          gespeicherte Mitglieder.{" "}
                          {!state.admin &&
                            "Neue Mitglieder müssen in deiner Nähe sein."}
                        </p>
                      </>
                    ) : (
                      <p className="organization-empty">
                        Die Mitgliederverwaltung steht der Leitung zur
                        Verfügung. Deine eigenen Ränge und deinen Dienststatus
                        findest du hier weiterhin.
                      </p>
                    ))}
                  {tab === "ranks" && (
                    <>
                      <div className="organization-ranks">
                        {selected.grades.map((grade) => (
                          <form
                            key={`${grade.grade}:${grade.label}:${grade.salary}`}
                            onSubmit={(e) => {
                              e.preventDefault();
                              const form = new FormData(e.currentTarget);
                              void run({
                                action: "grade",
                                grade: grade.grade,
                                label: form.get("label"),
                                salary: Number(form.get("salary")),
                              });
                            }}
                          >
                            <span className="rank-number">
                              {String(grade.grade).padStart(2, "0")}
                            </span>
                            <label>
                              Bezeichnung
                              <input
                                name="label"
                                defaultValue={grade.label}
                                required
                                minLength={2}
                                maxLength={40}
                                disabled={
                                  selected.kind === "faction" ||
                                  !selected.manage ||
                                  (!state.admin && grade.grade >= actorGrade)
                                }
                              />
                            </label>
                            {selected.kind === "job" && (
                              <label>
                                Gehalt ($)
                                <input
                                  name="salary"
                                  type="number"
                                  min={0}
                                  max={3500}
                                  defaultValue={grade.salary}
                                  required
                                  disabled={
                                    !selected.manage ||
                                    (!state.admin && grade.grade >= actorGrade)
                                  }
                                />
                              </label>
                            )}
                            {selected.kind === "job" && selected.manage && (
                              <button
                                className="menu-secondary"
                                disabled={
                                  busy ||
                                  (!state.admin && grade.grade >= actorGrade)
                                }
                              >
                                Speichern
                              </button>
                            )}
                          </form>
                        ))}
                      </div>
                      {selected.kind === "faction" && (
                        <p className="organization-hint">
                          Mitglied → Stellvertretung → Leitung. Die Leitung
                          verwaltet untergeordnete Ränge; Administratoren
                          vergeben Leitungsrechte.
                        </p>
                      )}
                      {state.admin && selected.kind === "job" && (
                        <AddGrade
                          busy={busy}
                          onSubmit={(command) => void run(command)}
                        />
                      )}
                    </>
                  )}
                  {tab === "funds" && (
                    <Funds org={selected} busy={busy} confirm={confirm} />
                  )}
                  {tab === "details" && state.admin && (
                    <form
                      className="organization-form"
                      onSubmit={(e) => {
                        e.preventDefault();
                        void run({
                          action: "rename",
                          label: new FormData(e.currentTarget).get("label"),
                        });
                      }}
                    >
                      <label>
                        Bezeichnung
                        <input
                          name="label"
                          defaultValue={selected.label}
                          required
                          minLength={2}
                          maxLength={40}
                        />
                      </label>
                      <p className="organization-hint">
                        Interne Kennung: {selected.name}. Sie bleibt für
                        angebundene Systeme erhalten.
                      </p>
                      <button className="primary" disabled={busy}>
                        Bezeichnung speichern ↗
                      </button>
                    </form>
                  )}
                </div>
              </>
            ) : (
              <div className="organization-empty">
                <h2>Platz für neue Teams.</h2>
                <p>
                  {state.admin
                    ? "Lege einen Beruf oder eine zusätzliche Fraktion an."
                    : "Du gehörst noch keiner Organisation an."}
                </p>
              </div>
            )}
          </section>
        </div>
        <footer className="menu-footer">
          <span
            role={error ? "alert" : "status"}
            className={error ? "organization-error" : ""}
          >
            {error ||
              notice ||
              "Beruf und Mitgliedschaften gehören zu deinem aktiven Charakter."}
          </span>
          <button
            className="menu-secondary"
            disabled={busy}
            onClick={() => void run({ action: "view" })}
          >
            {busy ? "Lädt …" : "Aktualisieren"} <UiIcon name="refresh" />
          </button>
        </footer>
      </main>
      {dialog && (
        <div className="organization-modal">
          <section
            role="dialog"
            aria-modal="true"
            aria-labelledby="org-confirm"
          >
            <p className="menu-kicker">BITTE BESTÄTIGEN</p>
            <h2 id="org-confirm">{dialog.title}</h2>
            <p>{dialog.text}</p>
            {error && (
              <p role="alert" className="organization-error">
                {error}
              </p>
            )}
            <div>
              <button
                className="menu-secondary"
                disabled={busy}
                onClick={() => setDialog(null)}
              >
                Abbrechen
              </button>
              <button
                className="primary"
                disabled={busy}
                onClick={() => void run(dialog.command)}
              >
                Bestätigen ↗
              </button>
            </div>
          </section>
        </div>
      )}
      {createOpen && (
        <div className="organization-modal">
          <section role="dialog" aria-modal="true" aria-labelledby="org-create">
            <p className="menu-kicker">EIN NEUES TEAM</p>
            <h2 id="org-create">Organisation anlegen</h2>
            <form
              className="organization-form"
              onSubmit={(e) => {
                e.preventDefault();
                const form = new FormData(e.currentTarget);
                void run({
                  action: "create",
                  kind: form.get("kind"),
                  name: form.get("name"),
                  label: form.get("label"),
                });
              }}
            >
              <label>
                Art
                <select aria-label="Art" name="kind">
                  <option value="job">Beruf / Dienststelle</option>
                  <option value="faction">Zusätzliche Fraktion</option>
                </select>
              </label>
              <label>
                Bezeichnung
                <input
                  name="label"
                  required
                  minLength={2}
                  maxLength={40}
                  placeholder="Los Santos Customs"
                />
              </label>
              <label>
                Interne Kennung
                <input
                  name="name"
                  required
                  pattern="[a-z][a-z0-9_]{1,31}"
                  maxLength={32}
                  placeholder="mechanic"
                />
              </label>
              <p className="organization-hint">
                Neue Berufe starten mit drei Rängen und ohne Gehalt. Konten und
                Lager werden beim nächsten Serverneustart verfügbar.
              </p>
              {error && (
                <p role="alert" className="organization-error">
                  {error}
                </p>
              )}
              <div>
                <button
                  type="button"
                  className="menu-secondary"
                  disabled={busy}
                  onClick={() => setCreateOpen(false)}
                >
                  Abbrechen
                </button>
                <button className="primary" disabled={busy}>
                  Anlegen ↗
                </button>
              </div>
            </form>
          </section>
        </div>
      )}
    </div>
  );
}
function Recruit({
  org,
  candidates,
  admin,
  actorGrade,
  busy,
  onSubmit,
}: {
  org: Organization;
  candidates: OrganizationPayload["candidates"];
  admin: boolean;
  actorGrade: number;
  busy: boolean;
  onSubmit: (command: Command) => void;
}) {
  return (
    <form
      className="organization-recruit"
      onSubmit={(e) => {
        e.preventDefault();
        const form = new FormData(e.currentTarget);
        onSubmit({
          action: "hire",
          target: Number(form.get("target")),
          grade: Number(form.get("grade")),
        });
      }}
    >
      <label>
        Charakter aufnehmen
        <select
          aria-label="Charakter aufnehmen"
          name="target"
          required
          defaultValue=""
        >
          <option value="" disabled>
            Charakter auswählen
          </option>
          {candidates.map((c) => (
            <option key={c.id} value={c.id}>
              {c.name} · ID {c.id}
            </option>
          ))}
        </select>
      </label>
      <label>
        Einstiegsrang
        <select aria-label="Einstiegsrang" name="grade">
          {org.grades
            .filter((g) => admin || g.grade < actorGrade)
            .map((g) => (
              <option key={g.grade} value={g.grade}>
                {g.label}
              </option>
            ))}
        </select>
      </label>
      <button className="menu-secondary" disabled={busy || !candidates.length}>
        Aufnehmen +
      </button>
    </form>
  );
}
function MemberRow({
  org,
  member,
  admin,
  actorGrade,
  disabled,
  onCommand,
}: {
  org: Organization;
  member: OrganizationMember;
  admin: boolean;
  actorGrade: number;
  disabled: boolean;
  onCommand: (command: Command, remove: boolean) => void;
}) {
  const [grade, setGrade] = useState(member.grade);
  return (
    <tr>
      <td>
        <strong>{member.name}</strong>
        {member.self && <small>Dein Charakter</small>}
      </td>
      <td>
        <select
          aria-label={`Rang von ${member.name}`}
          value={grade}
          disabled={disabled}
          onChange={(e) => setGrade(Number(e.target.value))}
        >
          {org.grades.map((g) => (
            <option
              key={g.grade}
              value={g.grade}
              disabled={!admin && g.grade >= actorGrade}
            >
              {g.label}
            </option>
          ))}
        </select>
      </td>
      <td>
        <span className={`member-status ${member.online ? "online" : ""}`}>
          {member.online ? "Verbunden" : "Offline"}
        </span>
      </td>
      <td>
        <div className="member-actions">
          <button
            disabled={disabled || grade === member.grade}
            onClick={() =>
              onCommand(
                { action: "promote", member: member.token, grade },
                false,
              )
            }
          >
            Rang ändern
          </button>
          <button
            className="danger"
            disabled={disabled}
            onClick={() =>
              onCommand({ action: "fire", member: member.token }, true)
            }
          >
            Entfernen
          </button>
        </div>
      </td>
    </tr>
  );
}
function Funds({
  org,
  busy,
  confirm,
}: {
  org: Organization;
  busy: boolean;
  confirm: (title: string, text: string, command: Command) => void;
}) {
  const [amount, setAmount] = useState("100");
  return (
    <div className="organization-funds">
      <span className="menu-kicker">GEMEINSCHAFTSKONTO</span>
      <strong>{org.balance === undefined ? "—" : currency(org.balance)}</strong>
      <p>
        {org.balance === undefined
          ? org.manage
            ? "Das Konto wird beim nächsten Serverstart geladen."
            : "Kontostand und Buchungen sind der Leitung vorbehalten."
          : "Ein- und Auszahlungen erfolgen über dein Bargeld."}
      </p>
      {org.finance && (
        <>
          <label>
            Betrag ($)
            <input
              type="number"
              min={1}
              max={100000}
              step={1}
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
            />
          </label>
          <div>
            {[
              ["deposit", "Einzahlen"],
              ["withdraw", "Auszahlen"],
            ].map(([action, label]) => (
              <button
                key={action}
                className="menu-secondary"
                disabled={
                  busy ||
                  !Number.isSafeInteger(Number(amount)) ||
                  Number(amount) < 1 ||
                  Number(amount) > 100000
                }
                onClick={() =>
                  confirm(
                    label,
                    `${currency(Number(amount))} ${action === "deposit" ? "in die Gemeinschaftskasse einzahlen" : "aus der Gemeinschaftskasse auszahlen"}?`,
                    { action, amount: Number(amount) },
                  )
                }
              >
                {label}
              </button>
            ))}
          </div>
        </>
      )}
    </div>
  );
}
function AddGrade({
  busy,
  onSubmit,
}: {
  busy: boolean;
  onSubmit: (command: Command) => void;
}) {
  return (
    <details className="organization-add-rank">
      <summary>+ Weiteren Rang anlegen</summary>
      <form
        className="organization-form"
        onSubmit={(e) => {
          e.preventDefault();
          const form = new FormData(e.currentTarget);
          onSubmit({
            action: "addGrade",
            grade: Number(form.get("grade")),
            rankName: form.get("rankName"),
            label: form.get("label"),
            salary: Number(form.get("salary")),
          });
        }}
      >
        <label>
          Rangnummer
          <input name="grade" type="number" min={0} max={99} required />
        </label>
        <label>
          Interner Rangname
          <input
            name="rankName"
            pattern="[a-z][a-z0-9_]{1,31}"
            required
            placeholder="officer"
          />
        </label>
        <label>
          Bezeichnung
          <input name="label" minLength={2} maxLength={40} required />
        </label>
        <label>
          Gehalt ($)
          <input
            name="salary"
            type="number"
            min={0}
            max={3500}
            defaultValue={0}
            required
          />
        </label>
        <button className="menu-secondary" disabled={busy}>
          Rang anlegen
        </button>
      </form>
    </details>
  );
}
