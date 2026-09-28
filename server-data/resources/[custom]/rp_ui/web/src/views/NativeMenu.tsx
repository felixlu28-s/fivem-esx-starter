import { useEffect, useRef, useState } from "react";
import { fetchNui, isBrowser } from "../lib/nui";
import { nativeKeys, type NativeMenuPayload } from "../lib/nativeui";
import { createNativePreviewController } from "../lib/nativePreview";
import { inputKey } from "../lib/menuToggle";

function Arrow({ direction }: { direction: "left" | "right" | "up" | "down" }) {
  return (
    <svg
      className={`native-arrow native-arrow-${direction}`}
      viewBox="0 0 16 16"
      aria-hidden="true"
    >
      <path d="m6 3 5 5-5 5" />
    </svg>
  );
}
export function NativeMenu({
  data,
  onClosed,
  toggleKey,
}: {
  data: NativeMenuPayload;
  onClosed: () => void;
  toggleKey?: string;
}) {
  const [menu, setMenu] = useState(data);
  const [error, setError] = useState("");
  const [pending, setPending] = useState(false);
  const current = useRef(data);
  const inflight = useRef(false);
  const root = useRef<HTMLElement>(null);
  const close = useRef(onClosed);
  const toggle = useRef(toggleKey);
  toggle.current = toggleKey;
  const demo = useRef(createNativePreviewController());
  close.current = onClosed;
  useEffect(() => {
    if (data.revision < current.current.revision) return;
    current.current = data;
    setMenu(data);
  }, [data]);
  useEffect(() => {
    root.current?.focus({ preventScroll: true });
    let mounted = true;
    const listener = async (event: KeyboardEvent) => {
      event.preventDefault();
      event.stopPropagation();
      const key = toggle.current && inputKey(event) === toggle.current ? "close" : nativeKeys[event.key];
      if (
        !key ||
        event.ctrlKey ||
        event.altKey ||
        event.metaKey ||
        inflight.current ||
        (event.repeat && (key === "enter" || key === "back" || key === "close"))
      )
        return;
      setError("");
      if (isBrowser()) {
        const next = key === "close" ? null : demo.current(key);
        if (!next) close.current();
        else {
          current.current = next;
          setMenu(next);
        }
        return;
      }
      const request = current.current;
      inflight.current = true;
      setPending(true);
      try {
        const result = await fetchNui("rp_nativeui:input", {
          key,
          session: request.session,
          revision: request.revision,
        });
        if (!mounted) return;
        if (
          result.nativeui &&
          result.nativeui.revision >= current.current.revision
        ) {
          current.current = result.nativeui;
          setMenu(result.nativeui);
        }
        if (result.closed && current.current.session === request.session)
          close.current();
        if (
          !result.ok &&
          !["stale_menu", "busy", "action_rejected"].includes(
            result.error ?? "",
          )
        )
          setError("Aktion nicht verfügbar. Bitte erneut versuchen.");
      } catch {
        if (mounted) setError("Keine Antwort. Bitte erneut versuchen.");
      } finally {
        inflight.current = false;
        if (mounted) setPending(false);
      }
    };
    window.addEventListener("keydown", listener, true);
    return () => {
      mounted = false;
      window.removeEventListener("keydown", listener, true);
    };
  }, []);
  const selected = menu.items[menu.selected - 1];
  const start = Math.max(
    0,
    Math.min(
      menu.selected - menu.visibleRows,
      menu.items.length - menu.visibleRows,
    ),
  );
  const visible = menu.items.slice(start, start + menu.visibleRows);
  const description = error || selected?.description || menu.description;
  return (
    <main
      className={`native-menu native-theme-${menu.theme}`}
      ref={root}
      tabIndex={-1}
      aria-label="Interaktionsmenü"
      onPointerDown={(e) => e.preventDefault()}
      onContextMenu={(e) => e.preventDefault()}
    >
      <header className="native-banner">
        <svg className="native-globe" viewBox="0 0 200 200" aria-hidden="true">
          <g fill="none" stroke="currentColor" strokeWidth="8">
            <circle cx="100" cy="100" r="88" />
            <ellipse cx="100" cy="100" rx="42" ry="88" />
            <path d="M12 100h176M28 48q72 35 144 0M28 152q72-35 144 0M100 12v176" />
          </g>
        </svg>
        <h1>{menu.title}</h1>
      </header>
      <div className="native-subtitle">
        <span>{menu.subtitle}</span>
        <span>
          {menu.selected} / {menu.items.length}
        </span>
      </div>
      <div
        className="native-rows"
        role="menu"
        aria-label={menu.subtitle}
        aria-busy={pending}
        aria-activedescendant={
          selected ? `native-row-${selected.id}` : undefined
        }
      >
        {visible.map((item, index) => (
          <div
            key={item.id}
            id={`native-row-${item.id}`}
            data-item={item.id}
            role={item.type === "checkbox" ? "menuitemcheckbox" : "menuitem"}
            aria-checked={item.type === "checkbox" ? item.checked : undefined}
            aria-disabled={item.disabled}
            aria-haspopup={item.type === "submenu" ? "menu" : undefined}
            className={`native-row${start + index + 1 === menu.selected ? " is-selected" : ""}${item.disabled ? " is-disabled" : ""}`}
          >
            <span className="native-row-label">{item.label}</span>
            <span className="native-row-value">
              {item.disabled ? (
                <svg
                  className="native-lock"
                  viewBox="0 0 16 20"
                  aria-hidden="true"
                >
                  <path d="M4 8V5a4 4 0 0 1 8 0v3M3 8h10v10H3z" />
                </svg>
              ) : item.type === "list" ? (
                <>
                  <Arrow direction="left" />
                  <span>{item.options[item.index - 1].label}</span>
                  <Arrow direction="right" />
                </>
              ) : item.type === "checkbox" ? (
                <span
                  className={`native-checkbox${item.checked ? " is-checked" : ""}`}
                  aria-hidden="true"
                >
                  {item.checked && (
                    <svg viewBox="0 0 18 18">
                      <path d="m3 9 4 4 8-9" />
                    </svg>
                  )}
                </span>
              ) : (
                <>
                  {item.rightLabel && <span>{item.rightLabel}</span>}
                  {item.type === "submenu" && <Arrow direction="right" />}
                </>
              )}
            </span>
          </div>
        ))}
        {!menu.items.length && (
          <div className="native-empty">Keine Einträge verfügbar.</div>
        )}
      </div>
      {menu.items.length > menu.visibleRows && (
        <div className="native-scroll" aria-hidden="true">
          <Arrow direction="up" />
          <Arrow direction="down" />
        </div>
      )}
      {description && (
        <p className={`native-description${error ? " is-error" : ""}`}>
          {description}
        </p>
      )}
      {selected?.hint && (
        <aside className="native-control-hint" aria-label={selected.hint.label}>
          <div className="native-control-keys" aria-hidden="true">
            {selected.hint.keys.map((key, index) => <kbd key={index}>{key}</kbd>)}
          </div>
          <div><strong>{selected.hint.label}</strong><span>{selected.hint.detail}</span></div>
        </aside>
      )}
    </main>
  );
}
