import { useEffect, useRef, useState } from "react";
import { UiIcon } from "../components/UiIcon";
import { ItemIcon } from "./ItemIcon";
import { fetchNui, isBrowser } from "../lib/nui";
import { commerceErrors, type CommercePayload } from "../lib/commerce";
import { demoCommerce } from "../lib/commercePreview";
const money = (v: number) => `$${v.toLocaleString("de-DE")}`;
export function CommerceView({
  data,
  onClose,
}: {
  data: CommercePayload;
  onClose: () => void;
}) {
  const [state, setState] = useState(data),
    [selected, setSelected] = useState(data.offers[0]?.id ?? "");
  const [category, setCategory] = useState("Alle"),
    [query, setQuery] = useState(""),
    [quantity, setQuantity] = useState(1);
  const [account, setAccount] = useState("money"),
    [busy, setBusy] = useState(false),
    [notice, setNotice] = useState("");
  const [now, setNow] = useState(Date.now()),
    [jobUntil, setJobUntil] = useState(Date.now() + (data.job?.remaining ?? 0));
  const alive = useRef(true),
    session = useRef(data.session),
    inFlight = useRef(false),
    completed = useRef("");
  const request = useRef<{ key: string; id: string } | undefined>(undefined);
  useEffect(() => {
    alive.current = true;
    return () => {
      alive.current = false;
    };
  }, []);
  useEffect(() => {
    session.current = data.session;
    setState(data);
    setJobUntil(Date.now() + (data.job?.remaining ?? 0));
  }, [data]);
  useEffect(() => {
    if (!state.job) return;
    const timer = window.setInterval(() => setNow(Date.now()), 100);
    return () => clearInterval(timer);
  }, [state.job]);
  const offer = state.offers.find((o) => o.id === selected) ?? state.offers[0];
  const craft = state.kind === "crafting",
    remaining = state.job ? Math.max(0, jobUntil - now) : 0;
  const categories = ["Alle", ...new Set(state.offers.map((o) => o.category))];
  async function act(action: string) {
    if (inFlight.current) return;
    inFlight.current = true;
    setBusy(true);
    setNotice("");
    const current = session.current,
      key = `${selected}:${quantity}:${account}`;
    if (!request.current || request.current.key !== key)
      request.current = { key, id: crypto.randomUUID() };
    try {
      const p = {
        session: current,
        action,
        offer: selected,
        quantity,
        account,
        request: request.current.id,
        token: state.job?.token,
      };
      const result = isBrowser()
        ? demoCommerce(state.kind, p)
        : await fetchNui("rp_commerce:action", p);
      if (!alive.current || current !== session.current) return;
      if (result.commerce) {
        setState(result.commerce);
        setJobUntil(Date.now() + (result.commerce.job?.remaining ?? 0));
        setNow(Date.now());
      }
      if (result.ok) {
        request.current = undefined;
        setNotice(
          action === "buy" || action === "recover"
            ? "Einkauf in deinen Taschen."
            : action === "finish"
              ? "Fertig. Dein Gegenstand ist im Inventar."
              : action === "cancel"
                ? "Herstellung abgebrochen."
                : "",
        );
      } else
        setNotice(
          commerceErrors[result.error ?? ""] ??
            "Die Aktion ist gerade nicht möglich. Bitte aktualisieren.",
        );
    } catch {
      if (alive.current)
        setNotice(
          "Die Antwort fehlt. Aktualisiere den Status; ein erneuter Versuch verwendet dieselbe Anfrage.",
        );
    } finally {
      inFlight.current = false;
      if (alive.current) setBusy(false);
    }
  }
  useEffect(() => {
    if (
      state.job &&
      remaining === 0 &&
      !busy &&
      completed.current !== state.job.token
    ) {
      completed.current = state.job.token;
      void act("finish");
    }
  }, [state.job, remaining, busy]);
  const missing = !!offer?.ingredients.some(
    (i) => i.owned < i.count * quantity,
  );
  const affordable =
    !offer ||
    (account === "money" ? state.cash : state.bank) >= offer.price * quantity;
  return (
    <main className="commerce-shell" aria-label={craft ? "Werkbank" : "Shop"}>
      <section className="commerce-catalog">
        <header>
          <div>
            <p className="eyebrow">
              {craft ? "HANDWERK" : "NAHVERSORGUNG"} · LOS SANTOS
            </p>
            <h1>
              <UiIcon name={craft ? "craft" : "shop"} />
              {state.label}
            </h1>
            <p>{state.subtitle}</p>
          </div>
          <div className="commerce-tools">
            <button
              aria-label="Aktualisieren"
              disabled={busy}
              onClick={() => void act("refresh")}
            >
              <UiIcon name="refresh" />
            </button>
            <button aria-label="Schließen" onClick={onClose}>
              <UiIcon name="close" />
            </button>
          </div>
        </header>
        <div className="commerce-search">
          <UiIcon name="search" />
          <input
            aria-label="Artikel suchen"
            placeholder={craft ? "Rezept finden …" : "Artikel finden …"}
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
        </div>
        <nav aria-label="Kategorien">
          {categories.map((c) => (
            <button
              key={c}
              aria-pressed={category === c}
              onClick={() => setCategory(c)}
            >
              {c}
            </button>
          ))}
        </nav>
        <div className="commerce-grid">
          {state.offers
            .filter(
              (o) =>
                (category === "Alle" || o.category === category) &&
                o.label.toLocaleLowerCase().includes(query.toLocaleLowerCase()),
            )
            .map((o) => (
              <button
                key={o.id}
                className="commerce-product"
                aria-pressed={offer?.id === o.id}
                onClick={() => {
                  setSelected(o.id);
                  setQuantity(1);
                }}
              >
                <span className="commerce-product-category">{o.category}</span>
                <ItemIcon name={o.icon} artwork={o.artwork} label={o.label}/>
                <strong>{o.label}</strong>
                <span>
                  {craft
                    ? `${o.seconds} Sek. · ${o.count} Stück`
                    : money(o.price)}
                </span>
              </button>
            ))}
        </div>
      </section>
      <aside className="commerce-detail" aria-label="Auswahl">
        {offer && (
          <>
            <div className="commerce-detail-hero">
              <span className="eyebrow">{offer.category}</span>
              <ItemIcon name={offer.icon} artwork={offer.artwork} label={offer.label}/>
              <h2>{offer.label}</h2>
              <p>{offer.description}</p>
              <div className="commerce-meta">
                <span>
                  {(offer.weight / 1000).toLocaleString("de-DE")} kg / Stück
                </span>
                <span>{offer.owned} in deinen Taschen</span>
              </div>
            </div>
            <div className="commerce-detail-body">
              {craft ? (
                <div className="commerce-ingredients">
                  <p className="eyebrow">BENÖTIGTE MATERIALIEN</p>
                  {offer.ingredients.map((i) => (
                    <div
                      key={i.name}
                      className={i.owned < i.count * quantity ? "missing" : ""}
                    >
                      <ItemIcon name={i.icon} artwork={i.artwork} label={i.label}/>
                      <span>{i.label}</span>
                      <strong>
                        {i.owned} / {i.count * quantity}
                      </strong>
                    </div>
                  ))}
                </div>
              ) : (
                <div
                  className="commerce-payment"
                  role="group"
                  aria-label="Zahlungsart"
                >
                  <button
                    aria-pressed={account === "money"}
                    disabled={busy}
                    onClick={() => setAccount("money")}
                  >
                    Bargeld<strong>{money(state.cash)}</strong>
                  </button>
                  <button
                    aria-pressed={account === "bank"}
                    disabled={busy}
                    onClick={() => setAccount("bank")}
                  >
                    Karte<strong>{money(state.bank)}</strong>
                  </button>
                </div>
              )}
              <label className="commerce-quantity">
                {craft ? "Durchgänge" : "Menge"}
                <span>
                  <button
                    aria-label="Menge verringern"
                    disabled={busy || !!state.job || quantity <= 1}
                    onClick={() => setQuantity((q) => q - 1)}
                  >
                    −
                  </button>
                  <input
                    aria-label="Menge"
                    type="number"
                    min="1"
                    max={state.maxQuantity}
                    value={quantity}
                    disabled={busy || !!state.job}
                    onChange={(e) =>
                      setQuantity(
                        Math.min(
                          state.maxQuantity,
                          Math.max(1, Math.floor(Number(e.target.value) || 1)),
                        ),
                      )
                    }
                  />
                  <button
                    aria-label="Menge erhöhen"
                    disabled={
                      busy || !!state.job || quantity >= state.maxQuantity
                    }
                    onClick={() => setQuantity((q) => q + 1)}
                  >
                    +
                  </button>
                </span>
              </label>
              <div className="commerce-total">
                <span>{craft ? "Ergebnis" : "Gesamt"}</span>
                <strong>
                  {craft
                    ? `${offer.count * quantity} × ${offer.label}`
                    : money(offer.price * quantity)}
                </strong>
              </div>
              {state.job ? (
                <div className="commerce-progress">
                  <div>
                    <span>
                      In Arbeit ·{" "}
                      {
                        state.offers.find((o) => o.id === state.job?.offer)
                          ?.label
                      }
                    </span>
                    <strong>{Math.ceil(remaining / 1000)} s</strong>
                  </div>
                  <progress
                    aria-label="Herstellungsfortschritt"
                    max={state.job.duration}
                    value={state.job.duration - remaining}
                  />
                  {remaining === 0 && (
                    <button disabled={busy} onClick={() => void act("finish")}>
                      Abschluss prüfen
                    </button>
                  )}
                  <button disabled={busy} onClick={() => void act("cancel")}>
                    Abbrechen
                  </button>
                </div>
              ) : (
                <button
                  className="commerce-submit"
                  disabled={
                    busy ||
                    (craft ? missing : !affordable || state.pending !== "none")
                  }
                  onClick={() => void act(craft ? "craft" : "buy")}
                >
                  <UiIcon name={craft ? "craft" : "shop"} />
                  {busy
                    ? "Wird verarbeitet …"
                    : craft
                      ? "Herstellen"
                      : "Kaufen"}
                </button>
              )}
              {craft && missing && (
                <p className="commerce-hint">
                  Dir fehlen Materialien. Du bekommst sie im 24/7 nebenan.
                </p>
              )}
              {state.pending !== "none" && (
                <div className="commerce-hint">
                  {state.pending === "paid"
                    ? "Eine bezahlte Bestellung wartet auf die Übergabe."
                    : "Eine unterbrochene Zahlung muss durch die Verwaltung geprüft werden."}
                  {state.pending === "paid" && (
                    <button disabled={busy} onClick={() => void act("recover")}>
                      Bestellung abholen
                    </button>
                  )}
                </div>
              )}
              <p className="commerce-notice" role="status">
                {notice}
              </p>
            </div>
          </>
        )}
      </aside>
    </main>
  );
}
