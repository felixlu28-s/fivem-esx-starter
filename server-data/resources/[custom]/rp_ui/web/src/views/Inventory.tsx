import {
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
  type MouseEvent,
} from "react";
import { errorLabel, fetchNui, isBrowser } from "../lib/nui";
import {
  inventoryErrors,
  kg,
  type InventoryAction,
  type InventoryItem,
  type InventoryPayload,
  type InventoryRecipient,
  type InventorySide,
  type InventoryStore,
} from "../lib/inventory";
import {
  previewInventoryAction,
  previewRecipients,
  previewRecipientStores,
} from "../lib/inventoryPreview";
import { useInventoryDrag } from "../lib/inventoryDrag";
import { ItemIcon } from "./ItemIcon";
import { UiIcon } from "../components/UiIcon";
import { ClothingImage } from "../components/ClothingImage";
import '../clothing.css';

type Selection = { side: InventorySide; slot: number };
type Context = Selection & { x: number; y: number; name: string };
function SlotContents({ slot, item, count = item?.count }: { slot: number; item?: InventoryItem; count?: number }) {
  return <>
    <span className="inventory-slot-number">{String(slot).padStart(2, "0")}</span>
    {item && <>
      <span className="inventory-slot-count">{count}<small> / {item.maxStack}</small></span>
      {item.clothing ? <ClothingImage artwork={item.artwork} category={item.clothing.image} color={item.clothing.color} label={item.label}/> : <ItemIcon name={item.icon} artwork={item.artwork} label={item.label}/>}
      {item.clothing?.worn && <span className="inventory-worn">Angezogen</span>}
      <span className="inventory-item-label" title={item.label}>{item.label.replace(/(munition|rucksack)/gi, "\u00ad$1")}</span>
    </>}
  </>;
}
export function Inventory({
  data: incoming,
  onClose,
}: {
  data: InventoryPayload;
  onClose: () => void;
}) {
  const [data, setData] = useState(incoming);
  const [selected, setSelected] = useState<Selection | null>(null);
  const [count, setCount] = useState(1);
  const [busy, setBusy] = useState(false);
  const busyRef = useRef(false);
  const [notice, setNotice] = useState("");
  const [context, setContext] = useState<Context | null>(null);
  const [removing, setRemoving] = useState(false);
  const [hover, setHover] = useState<{ item: InventoryItem; x: number; y: number } | null>(null);
  const tooltip = useRef<HTMLDivElement>(null);
  const [hoverPosition, setHoverPosition] = useState({ left: 0, top: 0 });
  const [recipients, setRecipients] = useState<InventoryRecipient[] | null>(
    null,
  );
  const [finding, setFinding] = useState(false);
  const [recipientError, setRecipientError] = useState("");
  const [demoStores, setDemoStores] = useState(previewRecipientStores);
  const requestVersion = useRef(0);
  const menu = useRef<HTMLElement>(null);
  const anchor = useRef<HTMLElement | null>(null);
  const [position, setPosition] = useState({ left: 0, top: 0 });
  const active =
    selected?.slot === 0
      ? data.own.backpack
      : selected &&
        data[selected.side]?.items.find((i) => i.slot === selected.slot);
  const closeContext = () => {
    requestVersion.current++;
    setContext(null);
    setRemoving(false);
    setRecipients(null);
    setFinding(false);
    setRecipientError("");
  };
  useEffect(() => {
    setData(incoming);
    setHover(null);
    closeContext();
  }, [incoming]);
  useEffect(
    () => () => {
      requestVersion.current++;
    },
    [],
  );
  useEffect(() => {
    if (selected && (!active || (context && active.name !== context.name))) {
      setSelected(null);
      closeContext();
    }
    if (active) setCount((c) => Math.max(1, Math.min(c, active.count)));
  }, [selected, active, context]);
  useLayoutEffect(() => {
    if (!context || !menu.current) return;
    const place = () => {
      const box = menu.current?.getBoundingClientRect();
      if (!box) return;
      setPosition({
        left: Math.max(
          8,
          Math.min(context.x, window.innerWidth - box.width - 8),
        ),
        top: Math.max(
          8,
          Math.min(context.y, window.innerHeight - box.height - 8),
        ),
      });
    };
    place();
    window.addEventListener("resize", place);
    return () => window.removeEventListener("resize", place);
  }, [context, recipients, finding, recipientError, removing]);
  useLayoutEffect(() => {
    const box = tooltip.current?.getBoundingClientRect();
    if (hover && box) setHoverPosition({
      left: Math.max(8, Math.min(hover.x, window.innerWidth - box.width - 8)),
      top: Math.max(8, Math.min(hover.y, window.innerHeight - box.height - 8)),
    });
  }, [hover]);
  useEffect(() => {
    if (!context) return;
    menu.current?.focus();
    const key = (e: KeyboardEvent) => {
      if (e.key !== "Escape") return;
      e.preventDefault();
      e.stopPropagation();
      closeContext();
      anchor.current?.focus();
    };
    window.addEventListener("keydown", key, true);
    return () => window.removeEventListener("keydown", key, true);
  }, [context]);
  const select = (side: InventorySide, item: InventoryItem) => {
    if (selected?.side !== side || selected.slot !== item.slot)
      setCount(item.count);
    setSelected({ side, slot: item.slot });
  };
  const openContext = (
    side: InventorySide,
    item: InventoryItem,
    element: HTMLElement,
    x: number,
    y: number,
  ) => {
    closeContext();
    setHover(null);
    select(side, item);
    anchor.current = element;
    setContext({ side, slot: item.slot, x, y, name: item.name });
  };
  const rightClick = (
    event: MouseEvent<HTMLElement>,
    side: InventorySide,
    item: InventoryItem,
  ) => {
    event.preventDefault();
    event.stopPropagation();
    const rect = event.currentTarget.getBoundingClientRect();
    openContext(
      side,
      item,
      event.currentTarget,
      event.clientX || rect.left + 12,
      event.clientY || rect.top + 12,
    );
  };
  const act = async (action: InventoryAction) => {
    if (busyRef.current) return;
    busyRef.current = true;
    setBusy(true);
    setNotice("");
    closeContext();
    pointer.cancel();
    try {
      if (isBrowser()) {
        const result = previewInventoryAction(data, action, demoStores);
        setData(result.inventory);
        if (result.recipients) setDemoStores(result.recipients);
        if (result.error)
          setNotice(inventoryErrors[result.error] ?? errorLabel(result.error));
        else if (action.action === "give")
          setNotice("Gegenstand übergeben · Browservorschau");
      } else {
        const result = await fetchNui("rp_inventory:action", {
          ...action,
          session: data.session,
          request: crypto.randomUUID(),
          ownRevision: data.own.revision,
          externalRevision: data.external?.revision,
        });
        if (result.inventory) setData(result.inventory);
        if (!result.ok)
          setNotice(
            inventoryErrors[result.error ?? ""] ?? errorLabel(result.error),
          );
        else if (action.action === "give") setNotice("Gegenstand übergeben.");
      }
    } catch {
      setNotice(
        "Antwort ausgeblieben. Bitte das Inventar schließen und erneut öffnen, bevor du erneut handelst.",
      );
    } finally {
      busyRef.current = false;
      setBusy(false);
    }
  };
  const fromSelection = (
    action: "use" | "drop" | "give",
    recipient?: string,
  ) => {
    if (selected?.side === "own" && selected.slot > 0)
      void act({ action, from: "own", slot: selected.slot, count, recipient });
  };
  const findRecipients = async () => {
    const version = ++requestVersion.current;
    setFinding(true);
    setRecipientError("");
    setRecipients(null);
    try {
      if (isBrowser()) setRecipients(previewRecipients);
      else {
        const result = await fetchNui("rp_inventory:recipients", {
          session: data.session,
        });
        if (version !== requestVersion.current) return;
        if (!result.ok || !result.recipients)
          setRecipientError(
            inventoryErrors[result.error ?? ""] ?? errorLabel(result.error),
          );
        else setRecipients(result.recipients);
      }
    } catch {
      if (version === requestVersion.current)
        setRecipientError("Personen konnten nicht geladen werden.");
    } finally {
      if (version === requestVersion.current) setFinding(false);
    }
  };
  const pointer = useInventoryDrag((drag, target) => {
    return act(target === "ground"
      ? { action: "drop", from: drag.side, slot: drag.slot, count: drag.count }
      : { action: "move", from: drag.side, slot: drag.slot, count: drag.count, to: target.side, target: target.slot });
  });
  useEffect(() => { pointer.cancel(); }, [incoming]);
  const take = () => {
    if (!active || selected?.side !== "external") return;
    const target =
      data.own.items.find(
        (i) => i.name === active.name && i.count + count <= i.maxStack,
      )?.slot ??
      Array.from({ length: data.own.slots }, (_, i) => i + 1).find(
        (slot) => !data.own.items.some((i) => i.slot === slot),
      );
    if (!target) {
      setNotice(inventoryErrors.no_slots);
      closeContext();
      return;
    }
    void act({
      action: "move",
      from: "external",
      slot: selected.slot,
      count,
      to: "own",
      target,
    });
  };
  const grid = (store: InventoryStore) => (
    <section className="inventory-store" aria-label={store.label}>
      <header className="inventory-store-heading">
        <span className="inventory-store-symbol" aria-hidden="true"><UiIcon name={store.side === "own" ? "bag" : "box"} /></span>
        <h2>{store.label}</h2>
        <div className="inventory-weight">
          <strong>
            {kg(store.weight)} <small>/ {kg(store.capacity)} kg</small>
          </strong>
          <span>
            {store.items.length} / {store.slots} Plätze
          </span>
        </div>
        {store.side === "own" && (
          <div className="inventory-tools">
            {store.backpack && (
              <button
                className="inventory-bag"
                aria-label="Angelegter Rucksack"
                title={store.backpack.label}
                onClick={(e) => {
                  e.stopPropagation();
                  const r = e.currentTarget.getBoundingClientRect();
                  openContext(
                    "own",
                    store.backpack!,
                    e.currentTarget,
                    r.left,
                    r.bottom,
                  );
                }}
                onContextMenu={(e) => rightClick(e, "own", store.backpack!)}
              >
                <UiIcon name="bag" />
              </button>
            )}
            <button
              onClick={onClose}
              aria-label="Inventar schließen"
              title="Schließen · Esc"
            >
              <UiIcon name="close" />
            </button>
          </div>
        )}
      </header>
      <div className="inventory-weight-track">
        <i
          style={{
            width: `${Math.min(100, (store.weight / Math.max(1, store.capacity)) * 100)}%`,
          }}
        />
      </div>
      <div
        className="inventory-grid"
        role="group"
        aria-label={`${store.label}: Plätze`}
        onScroll={() => { closeContext(); setHover(null); }}
      >
        {Array.from({ length: store.slots }, (_, index) => {
          const slot = index + 1,
            item = store.items.find((i) => i.slot === slot);
          const isSelected =
            selected?.side === store.side && selected.slot === slot;
          return (
            <button
              key={slot}
              className={`inventory-slot ${item ? "has-item" : ""} ${isSelected ? "is-selected" : ""} ${pointer.drag?.target?.side === store.side && pointer.drag.target.slot === slot ? `is-drop-target ${pointer.drag.settling ? "is-pending-target" : ""}` : ""} ${pointer.drag?.side === store.side && pointer.drag.slot === slot ? "is-drag-source" : ""}`}
              type="button"
              data-side={store.side}
              data-slot={slot}
              aria-label={`${store.label}, Platz ${slot}${item ? `: ${item.label}, ${item.count} Stück` : ", leer"}`}
              aria-pressed={isSelected}
              title={item?.attachments?.length ? undefined : item?.label}
              aria-describedby={hover?.item === item && !context && !pointer.drag ? "inventory-attachments" : undefined}
              onMouseEnter={(e) => {
                if (!item?.attachments?.length) return;
                const r = e.currentTarget.getBoundingClientRect();
                setHover({ item, x: r.right + 8, y: r.top });
              }}
              onMouseLeave={() => setHover(null)}
              onFocus={(e) => {
                if (!item?.attachments?.length) return;
                const r = e.currentTarget.getBoundingClientRect();
                setHover({ item, x: r.right + 8, y: r.top });
              }}
              onBlur={() => setHover(null)}
              disabled={busy}
              draggable={false}
              onDragStart={(e) => e.preventDefault()}
              onPointerDown={(e) => {
                if (item && !busy) {
                  const amount = selected?.side === store.side && selected.slot === slot ? count : item.count;
                  pointer.start(e, store.side, item, amount);
                  if (e.button === 0) { select(store.side, item); closeContext(); }
                }
              }}
              onPointerMove={pointer.move}
              onPointerUp={pointer.end}
              onPointerCancel={pointer.cancel}
              onLostPointerCapture={pointer.cancel}
              onClick={() => {
                if (pointer.consumeClick()) return;
                if (item) select(store.side, item);
                else if (
                  selected &&
                  selected.slot > 0 &&
                  (selected.slot !== slot || selected.side !== store.side)
                )
                  void act({
                    action: "move",
                    from: selected.side,
                    slot: selected.slot,
                    to: store.side,
                    target: slot,
                    count,
                  });
              }}
              onContextMenu={(e) => {
                if (item) rightClick(e, store.side, item);
              }}
              onKeyDown={(e) => {
                if (
                  item &&
                  (e.key === "ContextMenu" || (e.shiftKey && e.key === "F10"))
                ) {
                  e.preventDefault();
                  const r = e.currentTarget.getBoundingClientRect();
                  openContext(
                    store.side,
                    item,
                    e.currentTarget,
                    r.left + 12,
                    r.top + 12,
                  );
                }
              }}
            >
              <SlotContents slot={slot} item={item} />
            </button>
          );
        })}
      </div>
    </section>
  );
  return (
    <main
      className={`inventory-backdrop ${pointer.drag?.side === "own" && !pointer.drag.settling ? "is-dragging" : ""}`}
      onContextMenu={(e) => e.preventDefault()}
      onClick={closeContext}
    >
      <div className="inventory-outside-hint">
        <ItemIcon name="drop" />
        <span>Hier loslassen zum Ablegen</span>
      </div>
      <section
        className={`inventory-shell${data.external ? "" : " inventory-shell-single"}`}
        aria-label="Inventar"
        onDrop={(e) => {
          e.preventDefault();
          e.stopPropagation();
        }}
      >
        {grid(data.own)}
        {data.external && grid(data.external)}
      </section>
      {notice && !pointer.drag && <div className="inventory-notice" role="status">{notice}</div>}
      {hover && !pointer.drag && !context && <div ref={tooltip} className="inventory-tooltip" id="inventory-attachments" role="tooltip" style={hoverPosition}>
        <strong>{hover.item.label}</strong><small>Montierte Aufsätze</small>
        {hover.item.attachments?.map((a) => <span key={a.name}>{a.label}</span>)}
      </div>}
      {pointer.drag && (
        <div className="inventory-slot has-item inventory-drag-ghost" aria-hidden="true"
          style={{ left: pointer.drag.x - pointer.drag.offsetX, top: pointer.drag.y - pointer.drag.offsetY,
            width: pointer.drag.width, height: pointer.drag.height }}>
          <SlotContents slot={pointer.drag.settling ? pointer.drag.target?.slot ?? pointer.drag.slot : pointer.drag.slot} item={pointer.drag.item} count={pointer.drag.count} />
        </div>
      )}
      {context && active && (
        <aside
          ref={menu}
          className="inventory-context"
          style={position}
          role="dialog"
          aria-label="Gegenstandsaktionen"
          tabIndex={-1}
          onClick={(e) => e.stopPropagation()}
          onDrop={(e) => {
            e.preventDefault();
            e.stopPropagation();
          }}
        >
          <header>
            <ItemIcon name={active.icon} artwork={active.artwork} label={active.label}/>
            <div>
              <strong>{active.label}</strong>
              <small>
                {kg(active.weight)} kg / Stück
                {context.slot === 0
                  ? ` · +${active.bonusSlots} Plätze`
                  : ` · ${active.count} vorhanden`}
              </small>
            </div>
            <button aria-label="Aktionsmenü schließen" onClick={closeContext}>
              <UiIcon name="close" />
            </button>
          </header>
          {context.slot === 0 ? (
            <>
              <p className="inventory-context-hint">
                +{active.bonusSlots} Plätze · +{kg(active.bonusWeight)} kg
                Tragkraft
              </p>
              <button
                disabled={busy}
                onClick={() => void act({ action: "unequip" })}
              >
                <UiIcon name="bag" />
                Rucksack abnehmen
              </button>
              <p className="inventory-context-hint">
                Zum Weitergeben oder Ablegen zuerst abnehmen.
              </p>
            </>
          ) : (
            <>
              <label className="inventory-quantity">
                Menge
                <input
                  aria-label="Menge"
                  type="number"
                  min={1}
                  max={active.count}
                  step={1}
                  value={count}
                  disabled={busy}
                  onChange={(e) =>
                    setCount(
                      Math.max(
                        1,
                        Math.min(
                          active.count,
                          Math.trunc(Number(e.target.value) || 1),
                        ),
                      ),
                    )
                  }
                />
                <button
                  title="Gesamten Stapel auswählen"
                  onClick={() => setCount(active.count)}
                >
                  Alle
                </button>
              </label>
              {context.side === "own" ? (
                <>
                  <button
                    disabled={busy || !active.usable}
                    onClick={() => fromSelection("use")}
                  >
                    <ItemIcon name="hand" />
                    {active.clothing ? (active.clothing.worn ? 'Ausziehen' : 'Anziehen') : 'Benutzen'}
                  </button>
                  <button disabled={busy} onClick={() => fromSelection("drop")}>
                    <ItemIcon name="drop" />
                    Ablegen
                  </button>
                  {!!active.attachments?.length && <>
                    <button disabled={busy} aria-expanded={removing} onClick={() => setRemoving(!removing)}>
                      <UiIcon name="settings" />Aufsatz entfernen
                    </button>
                    {removing && <div className="inventory-attachment-options" aria-label="Montierte Aufsätze">
                      <p className="inventory-context-hint">Einzeln abnehmen und ins Inventar legen.</p>
                      {active.attachments.map((a) => <button key={a.name} disabled={busy}
                        onClick={() => void act({ action: "detach", from: "own", slot: active.slot, count: 1, attachment: a.name })}>
                        <span>{a.label}</span><UiIcon name="close" />
                      </button>)}
                    </div>}
                  </>}
                  <button
                    disabled={busy || finding}
                    onClick={() => void findRecipients()}
                  >
                    <UiIcon name="team" />
                    {finding ? "Suche Personen …" : "Geben"}
                  </button>
                </>
              ) : (
                <button disabled={busy} onClick={take}>
                  <ItemIcon name="hand" />
                  Aufnehmen
                </button>
              )}
              {(recipients || finding || recipientError) && (
                <div
                  className="inventory-recipients"
                  aria-label="Personen in der Nähe"
                >
                  <p className="inventory-context-hint">
                    {recipientError ||
                      (finding
                        ? "Suche im Umkreis von 3 Metern …"
                        : recipients?.length
                          ? "Empfänger auswählen · maximal 3 m"
                          : "Niemand in deiner Nähe.")}
                  </p>
                  {recipients?.map((person) => (
                    <button
                      key={person.token}
                      disabled={busy}
                      onClick={() => fromSelection("give", person.token)}
                    >
                      <UiIcon name="person" />
                      <span>{person.label}</span>
                      <small>{person.distance.toLocaleString("de-DE")} m</small>
                    </button>
                  ))}
                </div>
              )}
              <button
                className="inventory-context-apply"
                disabled={busy}
                onClick={closeContext}
              >
                <UiIcon name="check" />
                Menge fürs Ziehen übernehmen
              </button>
            </>
          )}
        </aside>
      )}
    </main>
  );
}
